require_relative 'helper'
require 'securerandom'

class TestPool < Minitest::Test
  class MockConnWrapper < Broker::ConnectionWrapper
    attr_accessor :id
    def initialize(opts={})
      @id = SecureRandom.uuid
      super(opts)
    end

    def handle(action, *args, &block)
      if action == :error
        self.last_error = args[0]
      end
    end

    def test(action, info)
      info[:conn] = self
      info[:action] = action

      if action == :wrong
        raise action
      end
    end
  end

  def setup
    @pool = Broker::Pool.new(
      wrapper_cls: MockConnWrapper,
      wrapper_args: {},
      max: 5
    )
  end

  def test_with
    info = {}
    assert_equal 0, @pool.count
    @pool.with {|conn|
      conn.test(:ok, info)
    }
    # 复用
    @pool.with {|conn|
      conn.test(:ok, info)
    }
    assert_equal 1, @pool.count
    assert_equal :ok, info[:action]
  end

  def test_with_error
    info = {}
    assert_equal 0, @pool.count
    assert_raises {
      @pool.with {|conn|
        conn.test(:wrong, info)
      }
    }
    assert_equal 0, @pool.count
    assert_equal :wrong, info[:action]
    assert info[:conn].closed?
    assert info[:conn].last_error != nil
  end

  def test_with_multi
    conn_map = {}

    # add 3 conn to pool
    (1..3).map do |i|
      Thread.new {
        @pool.with{|conn|
          conn_map[conn.id] = conn
          sleep 0.01
        }
      }
    end.each {|t| t.join }
    assert_equal 3, @pool.count

    # with10次，应复用前3个
    (1..10).map do |i|
      Thread.new {
        @pool.with{|conn|
          conn_map[conn.id] = conn
          sleep 0.01
        }
      }
    end.each {|t| t.join }


    assert_equal 10, conn_map.length
    assert_equal 5, @pool.count
    assert_equal 5, conn_map.select{|k,c| c.closed? }.length
  end

  def test_shutdown
    conn_map = {}

    # add 3 conn to pool
    (1..3).map do |i|
      Thread.new {
        @pool.with{|conn|
          conn_map[conn.id] = conn
          sleep 0.01
        }
      }
    end.each {|t| t.join }
    assert_equal 3, @pool.count
    assert_equal 3, conn_map.length

    @pool.shutdown
    assert_equal 0, @pool.count
    assert_equal 3, conn_map.select{|k,c| c.closed? }.length
  end
end
