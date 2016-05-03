module Broker
  class Configuration
    attr_accessor :broker_url
    attr_accessor :jobserver_url
    attr_accessor :pool_size, :worker_pool_size, :job_processer_size
    attr_accessor :timeout, :timer_interval
    attr_accessor :sync_config_handle

    def initialize
      @pool_size = 10
      @worker_pool_size = 1
      @job_processer_size = 1
      @timeout = @timer_interval = 5.0
      @timer_in
      @sync_config_handle = nil
    end

    def pool_work_size?
      pool_size > worker_pool_size
    end
  end
end
