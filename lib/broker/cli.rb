require 'logger'
module Broker
  class Cli
    cattr_accessor(:configuration, instance_accessor: true) { Broker::Configuration.new  }
    delegate :logger, to: :configuration
    attr_reader :service
    attr_accessor :routes

    def initialize(service, opts = {})
      @service = service
      @routes = {}
      @running = false
      @sub_reged_token = "" # 所有服务注册后，返回的监听凭证

      @synced_version = ""      # 已同步到的版本
      @synced_first = false # 首次同步成功

      @mutex = Mutex.new
      @synced_first_cv = ConditionVariable.new # 首次成功通知
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

    def worker_pool
      @worker_pool ||= ConnectionPool.new(size: pool_size, timeout: timeout) do
        Broker::Worker.new(configuration)
      end
    end

    def pool_size
      configuration.pool_size
    end

    def sync_config
      configuration.sync_config_handle
    end

    def invoke(*args)
      worker_pool.with do |worker|
        worker.exec(args)
      end
    end

    def sync(&block)
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
    end

    def register()
      puts "尝试注册服务: #{ topics.join(", ") }"
      res = invoke("reg", topics)
      if res[0] == "ok"
        @sub_reged_token = res[1]
        puts "注册服务成功！"
        return true
      end

      puts "注册服务失败: #{ res[1] }"
      return false
    end
    alias reg register

    def sync_loop(doing_check)
      while doing_check.call do
        invoke("sync", @name, @synced_ver)
        ack = res[0]
        ok = false
        case ack
        when "newest"
          puts "当前配置已经是最新配置"
        when "ok"
          info = JSON.parse(res[2])
          ok = sync_config.call(false, info)
          @synced_version = res[1]
        when "err"
          puts "同步配置拉取失败: #{ res[1] }"
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
          invoke("sub", @sub_reged_token)
          next if res[0] == "empty"

          if res[0] == "err"
            puts "订阅服务失败: #{ res[1] }"
            if res[1].include?("unregistered")
              raise MSStopError, "broker重启，需要重新注册"
            end
            next
          end

          if res[0] == "ok"
            req = Broker::Message.generate(res[1])
            topic = req.service
            resAck = req.build_res

            if handle = routes[topic]
              begin
                handle.call(req, resAck)
              rescue StandardError => err
                resAck.code = 500
                resAck.data = "服务处理失败：%s" % err
                puts "服务处理失败: #{ err }"
              end
            else
              resAck.code = 400
              resAck.data = "服务处理失败：找不到 %s 的相关处理" % service
            end

            res = invoke("res", resAck.to_json)
            if res[0] == "err"
              puts "订阅服务发送应答失败: #{ res[1] }"
            end
          end
        rescue MSStopError
          # 发送重启信号
          @mutex.synchronize{
            cv_restart.signal
          }
        rescue StandardError => err
          puts "订阅服务处理失败: #{ err }"
        end
      end
    end

    def run
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

      while true do
        break if register
        sleep SYNC_INTERVAL_DEFAULT
      end

      begin
        # 启动同步线程
        if sync_config
          Thread.new {
            sync_loop(doing_check)
          }
          # 等待首次同步成功的信号
          @mutex.synchronize{
            @synced_first_cv.wait(@mutex)
          }
          puts "首次同步成功"
        end

        # # 启动监听服务
        cv_restart = ConditionVariable.new # 需要重启
        @worker_size.times do |i|
          Thread.new{
            worker_loop(doing_check, cv_restart)
          }
        end

        # 等待重启信号
        @mutex.synchronize{
          cv_restart.wait(@mutex)
        }
      rescue StandardError=> err
        puts "微服务运行发现未处理错误: #{ err }"
      ensure
        doing = false
        puts "微服务重启……"
      end
    end 
  end
end
