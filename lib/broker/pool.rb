module Broker
  class ConnectionWrapper
    attr_accessor :last_error
    attr_reader :state

    def initialize(opts={})
      @state = 'pending'
      @opts = opts
      @last_error = nil
    end

    def connected?
      @state == "connected"
    end

    def closed?
      @state == "closed"
    end

    def connect
      return self if connected?
      handle(:connect)
      @state = 'connected'
      self
    end

    def err_is?(err, *err_cls_lst)
      Pool.err_is?(err, *err_cls_lst)
    end

    def close
      return self if closed?
      begin
        handle(:close)
      ensure
        @state = 'closed'
      end
      self
    end

    # 继承实例需要重写该方法
    def handle(action, *args, &block)
    end

    def inspect
      "#{self.class} @state=\"#{@state}\" @last_error=\"#{@last_error}\" @opts=\"#{@opts}\""
    end
  end

  class Pool
    @@poolMap = {}
    class << self
      def err_is?(err, *err_cls_lst)
        err_cls_lst.each do |err_cls|
          return true if err.is_a? err_cls
        end
        false
      end

      def pool_inst
        @@poolMap[self.to_s]
      end

      def config(url, pool_size=5, timeout=10)
        @@poolMap[self.to_s] ||= Broker::Pool.new(pool_opts(url, pool_size, timeout))
        self
      end

      def with(&block)
        pool_inst.with(&block)
      end

      def exec(cmd, *args, &block)
        pool_inst.with {|conn|
          conn.send(cmd, *args, &block)
        }
      end

      def shutdown
        pool_inst.shutdown
      end
    end

    def initialize(opts)
      @mutex = Mutex.new
      @conns = []
      @wrapper_cls = opts[:wrapper_cls]
      @wrapper_args = opts[:wrapper_args]
      @max = opts[:max] || 10
      @has_shutdown = false
    end

    def count
      @conns.length
    end

    def get
      c = nil
      @mutex.synchronize {
        c = if @conns.empty?
          @wrapper_cls.new(@wrapper_args)
        else
          @conns.shift
        end
      }
      c.connect
    end

    def put(conn)
      return unless conn.is_a? ConnectionWrapper
      need_close = true
      # 仅在conn无错，且pool未满时，加入pool
      if conn.last_error.nil? and conn.connected?
        @mutex.synchronize {
          if @conns.length < @max
            @conns << conn
            need_close = false
          end
        }
      end

      # 其余情况，直接关闭
      conn.close if @has_shutdown or need_close
      nil
    end

    def with(&block)
      conn = get
      begin
        return block.call conn
      rescue => err
        conn.handle(:error, err)
        raise
      ensure
        put conn
      end
    end

    def shutdown
      @mutex.synchronize {
        @has_shutdown = true
        @conns.each {|c|
          begin
            c.close
          rescue
          end
        }
        @conns = []
      }
    end
  end
end
