gem 'minitest'
require 'thread'
require 'minitest/pride'
require 'minitest/autorun'
require_relative '../lib/broker'


class Minitest::Test
  def build_msg_attrs
    @traceid = "trace#{rand}"
    @topic = "topic#{rand}"
    @channel = "channel#{rand}"
    @req_data = rand
    @res_data = rand
    @nav = "nav:#{rand}"
    @rid = "rid:#{rand}"
    @bid = "bid:#{rand}"
    @sendtime = Time.now.to_i
    @deadline = Time.now.to_i
    @code = (rand * 100).to_i.to_s

    @msg_res = Broker::Message.new
    @msg_res.action = "res"
    @msg_res.code = @code
    @msg_res.data = @res_data
    @msg_res.traceid = @traceid
    @msg_res.rid = @rid
    @msg_res.sendtime = @sendtime
    @msg_res.deadline = @deadline

    @msg_req = Broker::Message.new
    @msg_req.action = "req"
    @msg_req.topic = @topic
    @msg_req.channel = @channel
    @msg_req.nav = @nav
    @msg_req.data = @req_data
    @msg_req.traceid = @traceid
    @msg_req.rid = @rid
    @msg_req.bid = "local"
    @msg_req.sendtime = @sendtime
    @msg_req.deadline = @deadline
  end
end
