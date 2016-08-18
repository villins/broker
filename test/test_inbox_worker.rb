require_relative 'helper'

class TestInboxWorker < Minitest::Test
  def setup
    @manager = Broker::configure
    @worker = Broker::InboxWorker.new(@manager)
    @mock_redis = Minitest::Mock.new
    @manager.redis = @mock_redis
    build_msg_attrs
  end

  def test_process_req
    data = ['topic', @manager.pack(@msg_req)]
    @mock_redis.expect(:exec, data, [:blpop, Array, Hash])
    @mock_redis.expect(:exec, true, [:rpush, @manager.outbox("local"), String])
    result = @worker.process
    assert_equal "req", result
  end

  def test_process_res
    data = ['topic', @manager.pack(@msg_res)]
    @mock_redis.expect(:exec, data, [:blpop, Array, Hash])
    result = @worker.process
    assert_equal "res", result
  end

  def test_process_wrong_action
    bytes = @manager.pack(@msg_res)
    bytes["res"] = "xxx"
    data = ['topic', bytes]
    @mock_redis.expect(:exec, data, [:blpop, Array, Hash])
    assert_raises(Broker::ProtocolError) {
      @worker.process
    }
  end

  def test_inbox_empty
    @mock_redis.expect(:exec, nil, [:blpop, Array, Hash])
    result = @worker.process
    assert !result
  end
end
