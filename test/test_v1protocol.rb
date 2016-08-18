require_relative 'helper'

class TestV1Protocol < Minitest::Test
  def setup
    build_msg_attrs
  end

  def test_pack
    msg = Broker::Message.new
    msg.action = "req"
    msg.traceid = @traceid
    msg.topic = @topic
    msg.channel = @channel
    msg.data = @req_data
    msg.nav = @nav
    hs = MessagePack.unpack(Broker::V1Protocol.pack(msg))

    assert_equal "req", hs["act"]
    assert_equal @traceid, hs["tid"]
    assert_equal @topic, hs["topic"]
    assert_equal @channel, hs["chan"]
    assert_equal @req_data, hs["data"]
    assert_equal @nav, hs["nav"]
    assert_equal 1, (hs["dl"] - hs["st"]).to_i

    deadline = hs["dl"]
    rid = hs["rid"]

    msg = msg.to_res
    msg.code = @code
    msg.data = @res_data
    hs = MessagePack.unpack(Broker::V1Protocol.pack(msg))

    assert_equal "res", hs["act"]
    assert_equal @traceid, hs["tid"]
    assert_equal rid, hs["rid"]
    assert_equal deadline, hs["dl"]
    assert_equal @code, hs["code"]
    assert_equal @res_data, hs["data"]
    assert_equal 1, (hs["dl"] - hs["st"]).to_i
  end

  def test_unpack
    hs = {
      "act" => "req",
      "topic" => @topic,
      "chan" => @channel,
      "data" => @req_data,
      "nav" => @nav,
      "tid" => @traceid,
      "rid" => @rid,
      "bid" => @bid,
      "st" => @sendtime,
      "dl" => @deadline
    }

    msg = Broker::V1Protocol.unpack(MessagePack.pack(hs))

    assert_equal "req", msg.action
    assert_equal @topic, msg.topic
    assert_equal @channel, msg.channel
    assert_equal @nav, msg.nav
    assert_equal @traceid, msg.traceid
    assert_equal @rid, msg.rid
    assert_equal @bid, msg.bid
    assert_equal @req_data, msg.data
    assert_equal @sendtime, msg.sendtime
    assert_equal @deadline, msg.deadline
    assert_equal 1, msg.v

    hs = {
      "act" => "res",
      "code" => @code,
      "data" => @res_data,
      "tid" => @traceid,
      "rid" => @rid,
      "st" => @sendtime,
      "dl" => @deadline
    }

    msg = Broker::V1Protocol.unpack(MessagePack.pack(hs))
    assert_equal "res", msg.action
    assert_equal @traceid, msg.traceid
    assert_equal @rid, msg.rid
    assert_equal @code, msg.code
    assert_equal @res_data, msg.data
    assert_equal @sendtime, msg.sendtime
    assert_equal @deadline, msg.deadline
    assert_equal 1, msg.v
  end


end
