require 'json'
module Broker
  class Message
    # res code
    # 0 => OK
    # 2xx => Borker库内部调用错误
    # 3xx => 参数问题
    # 4xx => 超时、找不到地址等错误
    # 5xx => 业务或未知错误

    attr_accessor :bid
    attr_accessor :action, :topic, :channel
    attr_accessor :data
    attr_writer :sendtime, :rid, :traceid, :timeout, :deadline, :v

    @@next_id = 0
    @@max_id = 1000000

    class << self
      def trace(traceid)
        Thread.current["msg_traceid"] = traceid
      end

      def next_id
        id = 0
        SignalSync.lock(:msg_next_id) {
          if @@next_id < @@max_id
            @@next_id += 1
          else
            @@next_id = 1
          end
          id = @@next_id
        }
        id
      end
    end

    def to_res
      msg = Message.new
      msg.code = "0"
      msg.action = "res"
      msg.traceid = traceid
      msg.bid = bid
      msg.rid = rid
      msg.deadline = deadline
      msg.v = v
      msg
    end

    def to_res_json
      Oj.dump({
        code: code,
        data: data
      })
    end

    def v
      @v ||= 1
    end

    def rid
      @rid ||= "#{Process.pid}|#{Message.next_id}"
    end

    def traceid
      @traceid ||= Thread.current["msg_traceid"]
    end

    def nav
      @nav ||= ""
    end

    def nav=(v)
      @nav = v.to_s
    end

    def code
      @code ||= "0"
    end

    def code=(v)
      @code = v.to_s
    end

    def service
      [@topic, @channel].join(",")
    end

    def service=(url)
      @topic, @channel = url.split("/", 2)
    end

    def sendtime
      @sendtime ||= Time.now.to_i
    end

    def timeout
      @timeout ||= 1
    end

    def deadline
      @deadline ||= sendtime + timeout
    end

    def to_s
      inspect
    end
  end
end
