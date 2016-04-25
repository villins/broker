module Broker
  class Cli
    attr_accessor :conf

    def initialize(name, opts = {})
      @name = name
      @conn = Broker.broker_pool
      @logger = opts[:logger] || Logger.new(STDERR)
      @running = false
      @worker_size = opts[:worker_size] || WORKER_SIZE_DEFAULT

      @sub_reged_token = "" # 所有服务注册后，返回的监听凭证
      #@subMap = {}

      @sync_handle = Broker.sync_handle
      @synced_ver = ""      # 已同步到的版本
      @synced_first = false # 首次同步成功

      @mutex = Mutex.new
      @synced_first_cv = ConditionVariable.new # 首次成功通知

      @conf = {}
    end

    def request(service, params={}, nav="")
      options = {
        action: "req",
        service: service,
        data: params,
        nav: nav
      }
      req = Broker::Message.new options

      return @conn.exec(["req", req.to_json])
    end

    def sync(&block)
      @sync_handle = block
    end

    #def sub(service, &block)
      #@subMap[service] = block
    #end

    def job(tube, &block)
    end

    def register(service_reg)
      begin
        service_reg = Broker.services unless service_reg
        log(:info, "尝试注册服务：%s", service_reg)
        res = @conn.exec(["reg", service_reg])
        if res[0] == "ok"
          @sub_reged_token = res[1]
          log(:info, "注册服务成功！")
          return true
        end
        log(:error, "注册服务失败：%s", res[1])
      rescue StandardError => err
        log(:error, "注册服务失败：%s", err)
        log(:trace, err)
      end
      return false
    end
    alias reg register

    def log(level, msg, *args)
      if level == :trace && msg.respond_to?(:backtrace)
        @logger.send(:error, msg.backtrace.join("\n"))
        return
      end

      if args.length > 0
        msg = msg % args
      end
      @logger.send(level, msg)
    end

    def sync_loop(doing_check)
      while doing_check.call do
        begin
          res = @conn.exec(["sync", @name, @synced_ver])
          ack = res[0]
          ok = false
          case ack
          when "newest"
            log(:trace, "已是最新配置")
          when "ok"
            info = JSON.parse(res[2])
            ok = @sync_handle.call(false, info)
            @synced_ver = res[1]
          when "err"
            log(:error, "同步回应失败：%s", res[1])
          end

          # 若是第一次成功，则发出信号
          if !@synced_first && ok
            @synced_first = true
            @mutex.synchronize{
              @synced_first_cv.signal
            }
          end

          sleep SYNC_INTERVAL_DEFAULT
        rescue StandardError => err
          log(:error, "同步处理失败：%s", err)
          log(:trace, err)
        end
      end
    end

    def worker_loop(doing_check, cv_restart)
      while doing_check.call do
        begin
          res = @conn.exec(["sub", @sub_reged_token])
          if res[0] == "empty"
            next
          end

          if res[0] == "err"
            log(:error, "订阅服务失败：%s", res[1])
            if res[1].include?("unregistered")
              raise MSStopError, "broker重启，需要重新注册"
            end
            next
          end

          if res[0] == "ok"
            req = Broker::Message.generate(res[1])
            service = req.service
            resAck = req.build_res

            if handle = @subMap[service]
              begin
                handle.call(req, resAck)
              rescue StandardError => err
                resAck.code = 500
                resAck.data = "服务处理失败：%s" % err
                log(:error, "服务处理失败：%s", err)
                log(:trace, err)
              end
            else
              resAck.code = 400
              resAck.data = "服务处理失败：找不到 %s 的相关处理" % service
            end

            # log(:info, "process req.\nreq:%s\nres:%s\n", req.to_json, resAck.to_json)
            res = @conn.exec(["res", resAck.to_json])
            if res[0] == "err"
              log(:error, "订阅服务发送应答失败：%s", res[1])
            end
          end
        rescue MSStopError
          # 发送重启信号
          @mutex.synchronize{
            cv_restart.signal
          }
        rescue StandardError => err
          log(:error, "订阅服务处理失败：%s", err)
          log(:trace, err)
        end
      end
    end

    def run()
      while true
        run_loop
        sleep SYNC_INTERVAL_DEFAULT
      end
    end

    def run_loop()
      @synced_first = false
      doing = true
      doing_check = Proc.new { doing }

      begin
        # 注册服务
        service_reg = @subMap.keys.sort.join(",")
        while true do
          break if reg(service_reg)
          sleep SYNC_INTERVAL_DEFAULT
        end

        # 启动同步线程
        if @sync_handle
          Thread.new{
            sync_loop(doing_check)
          }
          # 等待首次同步成功的信号
          @mutex.synchronize{
            @synced_first_cv.wait(@mutex)
          }
          log(:info, "首次同步成功")
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
      rescue StandardError => err
        log(:error, "微服务运行发现未处理错误：%s", err)
        log(:trace, err)
      ensure
        doing = false
        log(:info, "微服务重启……")
      end
    end 
  end
end
