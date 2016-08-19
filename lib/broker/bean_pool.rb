require "beaneater"

module Broker
  class BeanConnectionWrapper < ConnectionWrapper
    def initialize(opts={})
      super(opts)

      @url = opts[:url]
      @conn = nil
    end

    def handle(action, *args, &block)
      case action
      when :connect
        @conn = Beaneater.new(@url)
      when :error
        err = args[0]
        # 若是链接相关问题，则放弃该链接
        if BeanPool.is_conn_err(err)
          self.last_error = err
        end
      when :close
        @conn.close
      end
      self
    end

    def method_missing(name, *args, &block)
      @conn.send(name, *args, &block)
    end
  end

  class BeanPool < Pool
    class << self
      def pool_opts(url, pool_size, timeout)
        {
          wrapper_cls: BeanConnectionWrapper,
          wrapper_args: {url: url, timeout: timeout},
          max: pool_size
        }
      end

      def is_conn_err(err)
        err_is?(err, Beaneater::UnexpectedResponse, Beaneater::NotConnected, EOFError, Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNREFUSED)
      end
    end
  end

end
