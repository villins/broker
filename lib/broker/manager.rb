require_relative "protocol/v1"

module Broker
  class Config
    # discard
    attr_accessor :pool_size

    attr_accessor :disable_signal

    attr_accessor :node_name
    attr_accessor :redis_url, :job_server_url
    attr_accessor :pop_timeout
    attr_accessor :service_worker_size, :job_worker_size
    attr_accessor :log_file, :log_level

    # discard
    attr_accessor :broker_url, :pool_size, :worker_pool_size

    def initialize(opts={})
      @disable_signal = opts[:disable_signal]
      @node_name = opts[:node_name] || "broker"
      @log_level = :info
      @pop_timeout = opts[:pop_timeout] || 5 # 拉取消息超时时间
      @service_worker_size = opts[:service_worker_size] || 5 # 服务处理worker数量
      @job_worker_size = opts[:job_worker_size] || 0 # Job处理worker数量

      @redis_url = opts[:redis_url] || "redis://127.0.0.1:6379" # redis server 地址
      @job_server_url = opts[:job_server_url] || "127.0.0.1:11300"  # beanstalkd 地址
    end
  end

  # 未兼容做处理
  class BlockWorker
    def initialize(tube, block)
      @tube = tube
      @block = block
    end

    def work(*args)
      if @block.nil?
        raise "tube #{@tube} job's block is nil"
      end
      @block.call(*args)
    end
  end

  # 未兼容做处理
  class BlockService
    def initialize(service, block)
      @service = service
      @block = block
    end

    def process(*args)
      if @block.nil?
        raise "service #{@service}'s block is nil"
      end
      @block.call(*args)
    end
  end

  class Manager
    attr_reader :conf, :logger, :service_map, :worker_map
    attr_accessor :inboxs, :redis, :beans
    alias_method :log, :logger

    @@inst = nil
    def self.instance(*args)
      @@inst ||= self.new(*args)
    end

    def initialize(opts={})
      @shutdown = false
      @conf = opts.is_a?(Config) ? opts : Broker::Config.new(opts)
      @logger = JsonLog.new_by_file(conf.node_name, conf.log_file, conf.log_level)


      SignalSync.add_locker(:msg_next_id)
      @protocol_map = {
        1 => V1Protocol
      }
      @res_waiter_map = {} # response waiter hash
      @inboxs = [inbox(Process.pid)] # 收件箱列表，里面有待处理的消息
      @service_map = {}
      @worker_map = {}
      @redis = RedisPool.config(
        @conf.redis_url,
        @conf.service_worker_size + @conf.job_worker_size,
        @conf.pop_timeout * 3  # redis connect timeout
      )
      @beans = BeanPool.config(
        @conf.job_server_url,
        @conf.job_worker_size,
        @conf.pop_timeout * 3
      )
    end

    def new_log(sub_name)
      JsonLog.new_log(
        [conf.node_name, sub_name].join("::"),
        conf.log_level
      )
    end

    def unpack(data_bytes)
      v = data_bytes[0].unpack("C")[0]
      protocol = get_protocol(v)
      msg_bytes = data_bytes[1..-1]
      protocol.unpack(msg_bytes)
    end

    def pack(msg)
      protocol = get_protocol(msg.v)
      msg_bytes = protocol.pack(msg)
      v = [msg.v].pack("C")
      v + msg_bytes
    end

    def outbox(msg)
      bid = if msg.is_a? Message
                msg.bid
              else
                msg.to_s
              end
      "ms:outbox:#{bid}"
    end

    def inbox(msg)
      topic = if msg.is_a? Message
                msg.topic
              else
                msg.to_s
              end
      "ms:inbox:#{topic}"
    end

    def get_protocol(ver)
      if protocol = @protocol_map[ver || 1]
        return protocol
      end
      raise ProtocolError.new("wrong version: #{ver}")
    end

    def get_worker(topic, channel=nil)
      @worker_map[tube_key(topic, channel)]
    end

    def add_worker(topic, channel, worker)
      @worker_map[tube_key(topic, channel)] = worker
    end

    def tube_key(topic, channel=nil)
      if channel != nil && channel != ""
        return [topic, channel].join("-")
      end
      return topic
    end

    def get_service(topic, channel)
      @service_map[service_key(topic, channel)]
    end

    def add_service(topic, channel, service)
      add_topic topic
      @service_map[service_key(topic, channel)] = service
    end

    def add_topic(topic)
      inbox = "ms:inbox:#{topic}"
      @inboxs << inbox unless @inboxs.include?(inbox)
    end


    def service_key(topic, channel)
      [topic, channel].join("/")
    end

    def request(*args)
      # array: service, data, nav, timeout_secs
      # hash: msg's attributes
      raise ArgumentError.new("request need 1 or more args") if args.length < 1

      hs = {}
      if args[0].is_a? Hash
        hs = args[0]
      else
        hs[:service],hs[:data],hs[:nav],hs[:timeout] = args
      end

      requestx(hs)
    end

    def requestx(hs={})
      msg = Message.new
      msg.action = hs[:action] || "req"

      if hs[:service]
        msg.service = hs[:service]
      else
        msg.topic = hs[:topic]
        msg.channel = hs[:channel]
      end

      if msg.action ==  "job"
        hs[:code] ||= [hs[:pri],hs[:delay],hs[:ttr]].join("|")
        msg.code = hs[:code]
      end
      msg.data = hs[:data]
      msg.nav = hs[:nav]
      msg.timeout = hs[:timeout] || 3

      msg_res = msg.to_res
      msg_res.code = "400"
      msg_res.data = "broker request timeout"

      begin
        @redis.exec :rpush, outbox("local"), pack(msg)
      rescue => err
        msg_res.code = "201" # local error
        msg_res.data = "#{err.class}:#{err.to_s}"
        return msg_res
      end

      waiter = SignalSync.waiter
      @res_waiter_map[msg.rid] = waiter
      waiter.wait(msg.timeout) {|evt, data|
        if evt == :after
          msg_res = data unless data.nil?
          @res_waiter_map.delete msg.rid
        end
      }

      msg_res
    end

    def response(msg_res)
      if waiter = @res_waiter_map[msg_res.rid]
        waiter.signal(msg_res)
      end
    end

    def put(*args)
      # put job
      # array: service, data, nav, timeout_secs
      # hash: msg's attributes
      raise ArgumentError.new("put need 1 or more args") if args.length < 1

      hs = {}
      if args[0].is_a? Hash
        hs = args[0]
      else
        hs[:service],hs[:data],hs[:nav],hs[:timeout] = args
        hs[:code] = ""
      end
      hs[:action] = "job"

      requestx(hs)
    end

    def on(service, proc_module=nil, &block)
      topic, channel = service.split("/", 2)
      if proc_module == nil
        proc_module = BlockService.new(service, block)
      end
      add_service(topic, channel, proc_module)
    end

    def job(tube_name, wrk_module=nil, &block)
      if wrk_module == nil
        wrk_module = BlockWorker.new(tube_name, block)
      end
      add_worker(tube_name, nil, wrk_module)
    end

    def shutdown
      @shutdown = true
    end

    def shutdown?
      @shutdown
    end

    def start_server
      logger.info("manager start")
      @shutdown = false

      signal_handle unless conf.disable_signal
      start_worker(InboxWorker, conf.service_worker_size)
      start_worker(JobWorker, conf.job_worker_size)

      while !@shutdown
        sleep 1
      end

      logger.info("manager stop")
    end

    def signal_handle
      Signal.trap("SIGTERM") do
        logger.info("manager recv signal SIGTERM")
        shutdown
      end

      Signal.trap("INT") do
        logger.info("manager recv signal INT")
        shutdown
      end
    end

    def start_worker(work_cls, count)
      count.times do |i|
        Thread.new {
          work_cls.new(self).run
        }
      end
    end
  end
end
