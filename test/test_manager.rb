require_relative 'helper'

class TestManager< Minitest::Test
  def setup
    @manager = Broker::configure
    build_msg_attrs
    @mock_redis = Minitest::Mock.new
    @manager.redis = @mock_redis
  end

  def test_add_get_service
    assert_nil @manager.get_service("topic1", "channel1")
    assert_nil @manager.get_service("topic1", "channel2")
    assert_nil @manager.get_service("topic2", "channel3")

    @manager.add_service("topic1", "channel1", 1)
    @manager.add_service("topic1", "channel2", 2)
    @manager.add_service("topic2", "channel3", 3)

    assert_equal 1, @manager.get_service("topic1", "channel1")
    assert_equal 2, @manager.get_service("topic1", "channel2")
    assert_equal 3, @manager.get_service("topic2", "channel3")

    check = [Process.pid, "topic1","topic2"].map{|v|@manager.inbox(v)}.join(",")
    assert_equal check, @manager.inboxs.sort.join(",")
  end

  def test_get_protocol
    p = @manager.get_protocol(nil)
    assert_equal 1, p.version

    p = @manager.get_protocol(1)
    assert_equal 1, p.version

    assert_raises {
      @manager.get_protocol(0)
    }
  end

  def test_pack_and_unpack
    msg = Broker::Message.new
    msg.action = "res"
    msg.v = 0
    msg.code = @code
    msg.data = @res_data
    msg.rid = @rid
    msg.traceid = @traceid
    msg.bid = @bid

    assert_raises {
      @manager.pack(msg)
    }

    msg.v = 1
    data = @manager.pack msg

    v = data[0].unpack("C")[0]
    assert_equal 1, v
    msg_res = @manager.unpack data

    assert_equal 1, msg_res.v
    assert_equal @code, msg_res.code
    assert_equal @res_data, msg_res.data
    assert_equal @rid, msg_res.rid
    assert_equal @traceid, msg_res.traceid
  end

  def test_inbox
    assert_equal "ms:inbox:1", @manager.inbox(1)
    msg = Broker::Message.new
    msg.topic = "hello"
    assert_equal "ms:inbox:hello", @manager.inbox(msg)
  end

  def test_outbox
    assert_equal "ms:outbox:1", @manager.outbox(1)
    msg = Broker::Message.new
    msg.bid = "ba"
    assert_equal "ms:outbox:ba", @manager.outbox(msg)
  end

  def test_request_success
    @mock_redis.expect(:exec, true, [:rpush, @manager.outbox("local"), String])

    # request will build next rid
    next_rid = "#{Process.pid}|#{Broker::Message.next_id+1}"

    Thread.new {
      sleep 0.01
      msg_res = Broker::Message.new
      msg_res.code = @code
      msg_res.data = @res_data
      msg_res.rid = next_rid
      msg_res.v = 1
      @manager.response(msg_res)
    }

    res = @manager.request("#{@topic}/#{@channel}", @req_data, @nav, 1)
    assert_equal @code, res.code
    assert_equal @res_data, res.data
    assert_equal 1, res.v
  end

  def test_request_timeout
    @mock_redis.expect(:exec, true, [:rpush, @manager.outbox("local"), String])

    res = @manager.request("#{@topic}/#{@channel}", @req_data, @nav, 0.01)
    assert_equal "400", res.code
  end

  def test_request_error
    # mock_redis unmocked method rpush
    res = @manager.request("#{@topic}/#{@channel}", @req_data, @nav, 0.01)
    assert_equal "201", res.code
    assert_match ":exec", res.data
  end

  def test_put
  end

end
