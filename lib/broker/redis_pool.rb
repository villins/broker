require "redis"

module Broker
  class RedisConnectionWrapper < ConnectionWrapper
    def initialize(opts={})
      super(opts)

      @url = opts[:url]
      @timeout = opts[:timeout] || 10
      @conn = nil
    end

    def handle(action, *args, &block)
      case action
      when :connect
        @conn = Redis.new(
          url: @url,
          driver: :hiredis,
          timeout: @timeout
        )
      when :error
        err = args[0]
        self.last_error = err if err.is_a? Redis::BaseConnectionError
      when :close
        @conn.close
      end
    end

    def method_missing(name, *args, &block)
      @conn.send(name, *args, &block)
    end
  end

  class RedisPool < Pool
    class << self
      def pool_opts(url, pool_size, timeout)
        {
          wrapper_cls: RedisConnectionWrapper,
          wrapper_args: {url: url, timeout: timeout},
          max: pool_size
        }
      end

      def cache(key, timeout_sec, &block)
        data = self.exec :get, key
        if data.nil?
          data = block.call
          self.exec :set, key, data.to_msgpack, ex: timeout_sec
        else
          data = MessagePack.unpack(data)
        end
        data
      end
    end
  end
end
