require_relative 'helper'

class TestMessage < Minitest::Test
  def setup
    @msg = Broker::Message.new
    build_msg_attrs
  end

  def test_trace
    Broker::Message.trace nil
    assert_nil @msg.traceid
    Broker::Message.trace @traceid
    assert_equal @traceid, @msg.traceid
  end

  def test_sendtime
    t1 = @msg.sendtime
    t2 = @msg.sendtime
    assert_equal t1, t2

    @msg.sendtime = @sendtime
    assert_equal @sendtime, @msg.sendtime
  end

  def test_deadline
    t1 = @msg.sendtime
    t2 = @msg.deadline
    t3 = @msg.deadline
    assert_equal t2, t3
    assert_equal 1, t2 - t1

    @msg.deadline = nil
    @msg.timeout = 3
    t2 = @msg.deadline
    assert_equal 3, t2 - t1

    @msg.deadline = @deadline
    t2 = @msg.deadline
    assert_equal @deadline, t2
  end

  def test_to_res
    @msg.traceid = @traceid
    msg_res = @msg.to_res
    assert_equal "0", msg_res.code
    assert_equal @msg.deadline, msg_res.deadline
    assert_equal @msg.rid, msg_res.rid
    assert_equal @msg.bid, msg_res.bid
  end

  def test_rid
    ids = []
    id_start = Broker::Message::next_id + 1
    id_end = id_start + 5
    ts = (1..5).map {|i|
      Thread.new {
        ids << "#{Process.pid}|#{Broker::Message.next_id}"
      }
    }
    ids << @msg.rid
    ts.each {|t| t.join}
    ids = ids.map {|id|
      _, v = id.split("|")
      v
    }
    assert_equal(
     (id_start..id_end).to_a.join(",").split(",").sort.join(","),
     ids.sort.join(",")
    )
  end

  def test_service
    @msg.service = "a/b/c"
    assert_equal "a", @msg.topic
    assert_equal "b/c", @msg.channel
  end
end
