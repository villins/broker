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
    # first byte is version
    data = @manager.pack @msg_req
    v = data[0].unpack("C")[0]
    assert_equal 1, v

    # unpack req
    msg = @manager.unpack data
    assert_equal msg.rid, @msg_req.rid
    assert_equal msg.bid, @msg_req.bid
    assert_equal msg.traceid, @msg_req.traceid
    assert_equal msg.deadline, @msg_req.deadline
    assert_equal msg.sendtime, @msg_req.sendtime
    assert_equal msg.v, @msg_req.v
    assert_equal msg.action, @msg_req.action
    assert_equal msg.topic, @msg_req.topic
    assert_equal msg.channel, @msg_req.channel
    assert_equal msg.data, @msg_req.data


    # req => res, pack and unpack res
    msg = msg.to_res
    data = @manager.pack msg
    msg_res = @manager.unpack data


    # check req and res
    assert_equal "0", msg_res.code
    assert_equal "res", msg_res.action
    assert_equal @msg_req.rid, msg_res.rid
    assert_equal @msg_req.bid, msg_res.bid
    assert_equal @msg_req.traceid, msg_res.traceid
    assert_equal @msg_req.deadline, msg_res.deadline
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

  def test_res_faster_bug
    queue = Queue.new

    worker = Thread.new {
      res = queue.pop()
      @manager.response(res)
    }

    @mock_redis.expect(:exec, true) do |m, topic, data|
      result = m == :rpush
      if result
        msg = @manager.unpack(data)
        queue.push(msg.to_res)
        sleep 0.5
      end
      result
    end

    res = @manager.request("#{@topic}/#{@channel}", @req_data, @nav, 1)
    assert_equal "0", res.code
  end

  def test_put
  end

end
