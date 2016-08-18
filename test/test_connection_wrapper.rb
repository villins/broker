require_relative 'helper'

class TestConnectionWrapper < Minitest::Test
  class MockConnWrapper < Broker::ConnectionWrapper
    attr_accessor :try

    def initialize
       @try = nil
       @mapCount = {}
       super
    end

    def count(action)
      @mapCount[action].to_i
    end

    def handle(action, *args, &block)
      v = @mapCount[action].to_i
      v += 1
      @mapCount[action] = v

      if @try == "close_error" && action == :close
        raise @try
      end
    end

    def test(*args, &block)
      n = 0
      args.each {|v| n += v}
      n = block.call(n) if block
      n
    end
  end

  def setup
    @wrapper = MockConnWrapper.new
  end

  def test_connect_and_close
    assert_equal 0, @wrapper.count(:connect)
    assert_equal 0, @wrapper.count(:close)
    assert !@wrapper.connected?
    assert !@wrapper.closed?
    @wrapper.connect
    assert @wrapper.connected?
    @wrapper.close
    assert @wrapper.closed?
    assert_equal 1, @wrapper.count(:connect)
    assert_equal 1, @wrapper.count(:close)
  end

  def test_close_with_error
    @wrapper.try = "close_error"
    assert !@wrapper.closed?
    assert_raises {
      @wrapper.close
    }
    assert @wrapper.closed?
  end

  def test_method_missing
    n = @wrapper.test 1,2
    assert_equal 3, n

    n = @wrapper.test(1,2) {|i| i+1 }
    assert_equal 4, n
  end
end
