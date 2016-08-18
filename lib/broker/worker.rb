module Broker
  class Worker
    def initialize(manager)
      @manager = manager
      @logger = manager.new_log(self.class)
    end

    def run
      while !@manager.shutdown?
        begin
          process
        rescue => err
          @logger.error(err)
        end
      end
    end

    def process
      # 具体继承worker，重写该方法，实现处理逻辑
      # 注意处理频率不要太频繁，导致CPU占用过高
      sleep 1
    end

    def logger
      @logger
    end
    alias_method :log, :logger

  end

end
