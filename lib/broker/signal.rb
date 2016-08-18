module Broker
  class SignalWaiter
    def initialize(mutex=nil)
      @mutex = mutex || Mutex.new
      @cv = ConditionVariable.new
      @data = nil
    end

    def wait(secs=nil, &block)
      @mutex.synchronize{
        @data = nil
        block.call(:before, nil) if block
        @cv.wait(@mutex, secs)
        block.call(:after, @data) if block
      }
    end

    def signal(data=nil)
      @mutex.synchronize{
        @data = data
        @cv.signal
      }
    end
  end

  class SignalSync
    @@mutex_hs = {}
    @@mutex = Mutex.new

    class << self
      def waiter
        Thread.current[:signal_waiter] ||= SignalWaiter.new
      end

      def add_locker(*kinds)
        @@mutex.synchronize {
          kinds.each {|kind|
            @@mutex_hs[kind] = Mutex.new if @@mutex_hs[kind].nil?
          }
        }
      end

      def get_locker(kind)
        @@mutex_hs[kind]
      end

      def lock(kind, &block)
        (@@mutex_hs[kind] || @@mutex).synchronize(&block)
      end
    end
  end
end
