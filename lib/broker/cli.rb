require 'logger'
require 'broker/configuration'

module Broker
  class Cli
    attr_accessor :configuration
    attr_reader :name
    attr_accessor :routes, :job_routes

    def initialize
      @routes = {}
      @job_routes = {}
      @running = false
      @configuration = Broker::Configuration.new
      @sub_reged_token = "" # 所有服务注册后，返回的监听凭证

      @synced_version = ""      # 已同步到的版本
      @synced_first = false # 首次同步成功

      @mutex = Mutex.new
      @synced_first_cv = ConditionVariable.new # 首次成功通知
    end

    def request(service, params={}, nav="")
      request_broker("req_send", service, params, nav)
    end

    def put(tube, params={}, nav="")
      request_broker("job_send", tube, params, nav)
    end

    def request_broker(action, service, params, nav)
      logger.info "#{action} => [#{[service, params, nav].join(",")}]"

      req = Broker::Message.new
      req.action = action
      req.service = service
      req.data = params
      req.nav = nav

      cmds, data = req.to_res
      cmds, data = invoke(cmds, data)
      res = Broker::Message.from_res cmds, data

      if res.action == "err"
        logger.error "res_recv <= #{cmds.join(',')}"
      else
        logger.info "res_recv <= \ncode: #{res.code}\ndata: #{res.data}"
      end
      res
    end

    def worker_pool_size
      configuration.worker_pool_size
    end

    def timeout
      configuration.timeout
    end

    def timer_interval
      configuration.timer_interval
    end

    def worker_options
      {
        timeout:    configuration.timeout,
        broker_url: configuration.broker_url
      }
    end

    def worker_pool
      @worker_pool ||= ConnectionPool.new(size: pool_size, timeout: timeout) do
        Broker::Worker.new(worker_options)
      end
    end

    def pool_size
      configuration.pool_size
    end

    def config_handle
      configuration.sync_config_handle
    end

    def sync_config(block)
      configuration.sync_config_handle = block
    end

    def subscribe(topic, &block)
      routes[topic] = block
    end
    alias sub subscribe
    alias on subscribe

    def topics
      routes.keys
    end

    def job(tube, &block)
      job_routes[tube] = block
    end

    def register()
      logger.info "尝试注册服务: #{ topics.join(", ") }"
      res, data = invoke(["reg", topics.join(",")])
      if res[0] == "ok"
        @sub_reged_token = res[1]
        logger.info "注册服务成功！"
        return true
      end

      logger.error "注册服务失败: #{ res[1] }"
      return false
    end
    alias reg register

    def sync_loop(doing_check)
      while doing_check.call do
        res, data = invoke(["sync", @name, @synced_version])
        ack = res[0]
        ok = false
        case ack
        when "newest"
          # 若为第一次，即使未返回配置信息，也应该回调
          # 由服务配置回调决定是否可以进一步提供服务
          unless @synced_first
            ok = config_handle.call(true, nil)
            logger.info "（首次）配置未有更新，处理结果：#{ok}"
          end
        when "ok"
          ok = config_handle.call(false, data)
          @synced_version = res[1]
          logger.info "配置有更新，处理结果：#{ok}"
        when "err"
          logger.error "同步配置拉取失败: #{ res[1] }"
        end

        # 若是第一次成功，则发出信号
        if !@synced_first && ok
          @synced_first = true
          @mutex.synchronize{
            @synced_first_cv.signal
          }
        end

        sleep timer_interval
      end
    end

    def worker_loop(doing_check, cv_restart)
      while doing_check.call do
        begin
          res, data = invoke(["pull", @sub_reged_token])
          next if res[0] == "empty"

          if res[0] == "err"
            logger.info "订阅服务失败: #{ res[1] }"
            if res[1].include?("unregistered")
              raise MSStopError, "broker重启，需要重新注册"
            end
            next
          end

          if res[0] == "req_recv"
            req = Broker::Message.from_res(res, data)
            rep = Broker::Message.from_res(res, data).response


            logger.info "req_recv <= [#{[req.service, req.data, req.nav].join(",")}]"

            if handle = routes[req.service]
              begin
                handle.call(req, rep)
              rescue StandardError => err
                rep.code = "500"
                rep.data = "服务处理失败：%s" % err
                log_backtrace err
              end
            else
              rep.code = "400"
              rep.data = "服务处理失败：找不到 %s 的相关处理" % req.service
            end

            logger.info "res_send => \ncode:#{rep.code}\ndata:#{rep.data}"

            cmds, data = rep.to_res
            res, data = invoke(cmds, data)
            if res[0] == "err"
              logger.info "订阅服务发送应答失败: #{ res[1] }"
            end
          end
        rescue MSStopError
          # 发送重启信号
          @mutex.synchronize{
            cv_restart.signal
          }
        rescue StandardError => err
          logger.error "订阅服务处理失败: #{ err }"
          log_backtrace err
        end
      end
    end

    def job_process(doing_check)
      while doing_check.call do
        begin
          client = Beaneater.new(configuration.jobserver_url)
          job_routes.each{|tube, cb|
            client.jobs.register(tube) do |job|
              begin
                cb.call(job)
              rescue Beaneater::JobNotReserved
                raise
              rescue => err
                logger.error "任务(#{ tube })处理失败：#{ err }"
                log_backtrace err
                raise
              end
            end
          }

          Thread.new{
            begin
              client.jobs.process!
            rescue => e
              logger.error "Beanstalkd处理失败：#{ err }"
              log_backtrace err
              client.close
            end

          }

          # 循环检测
          while doing_check.call && client.connection.connection do
            sleep 0.1
          end
          client.close if client.connection.connection
        rescue StandardError => err
          logger.error "任务初始化失败：#{ err }"
          log_backtrace err
          sleep timer_interval
        end
      end
    end

    def run(name = nil)
      setup_signals
      @name = name if name
      @running = true
      while @running
        run_loop
        sleep timer_interval
      end
    end

    def run_loop()
      @synced_first = false
      doing = true
      doing_check = Proc.new { doing }

      begin
        while true do
          break if register
          sleep SYNC_INTERVAL_DEFAULT
        end

        # 启动同步线程
        if config_handle
          Thread.new {
            sync_loop(doing_check)
          }
          # 等待首次同步成功的信号
          @mutex.synchronize{
            @synced_first_cv.wait(@mutex)
          }
          logger.info "首次同步成功"
        else
          logger.warn "未设置配置更新回调"
        end

        configuration.broker_url = "broker://127.0.0.1:6636" unless configuration.broker_url
        logger.info "链接到 broker 服务为: #{ configuration.broker_url }"

        # # 启动监听服务
        cv_restart = ConditionVariable.new # 需要重启
        worker_pool_size.times do |i|
          Thread.new{
            worker_loop(doing_check, cv_restart)
          }
        end

        unless job_routes.empty?
          configuration.jobserver_url = "127.0.0.1:11300" unless configuration.jobserver_url
          logger.info "链接到 jobserver 服务为: #{ configuration.jobserver_url }"

          configuration.job_processer_size.times do |i|
            Thread.new{
              job_process(doing_check)
            }
          end
        end

        # 等待重启信号
        @mutex.synchronize{
          cv_restart.wait(@mutex)
        }
      rescue StandardError=> err
        logger.error "微服务运行发现未处理错误: #{ err }"
        log_backtrace err
      ensure
        doing = false
        logger.info "\n\n微服务重启……"
      end
    end

    def close
      worker_pool.shutdown { |worker| worker.disconnect }
    end

    def shutdown
      @running = false
    end

    def setup_signals
      Signal.trap("INT") {
        shutdown
        exit
      }

      Signal.trap("TERM") {
        shutdown
        exit
      }
    end

    def invoke(cmds, data=nil)
      worker_pool.with do |worker|
        worker.exec(cmds, data)
      end
    end

    def logger
      Broker::Logging.logger
    end

    def log_backtrace(err)
      if err.respond_to?(:backtrace)
        logger.error err.backtrace.join("\n")
      end
    end
  end
end
