class DateTime
  def to_msgpack(pk = nil)
    to_formatted_s(:utc).to_msgpack(pk)
  end
end

module Broker
  class V1Protocol
    class << self
      def version
        1
      end

      def pack(msg)
        action = msg.action
        msg_hs = case action
        when "req"
          {
            "topic" => msg.topic,
            "chan" => msg.channel || "",
            "nav" => msg.nav || "",
            "data" => msg.data
          }
        when "job"
          {
            "topic" => msg.topic,
            "chan" => msg.channel || "",
            "nav" => msg.nav || "",
            "data" => msg.data,
            "code" => msg.code || ""
          }
        when "res"
          {
            "code" => msg.code || "0",
            "data" => msg.data
          }
        else
          raise ProtocolError.new("wrong pack action: #{msg.action}")
        end
        msg_hs["bid"] = msg.bid || ""
        msg_hs["tid"] = msg.traceid || ""
        msg_hs["act"] = action
        msg_hs["rid"] = msg.rid
        msg_hs["st"] = msg.sendtime
        msg_hs["dl"] = msg.deadline
        MessagePack.pack(msg_hs)
      end

      def unpack(msg_bytes)
        msg_hs = MessagePack.unpack(msg_bytes)
        msg = Message.new
        msg.action = msg_hs["act"]
        case msg.action
        when "req", "job"
          msg.topic = msg_hs["topic"]
          msg.channel = msg_hs["chan"]
          msg.nav = msg_hs["nav"]
          msg.data = msg_hs["data"]
        when "res"
          msg.code = msg_hs["code"]
          msg.data = msg_hs["data"]
        else
          raise ProtocolError.new("wrong unpack action: #{msg.action}")
        end
        msg.traceid = msg_hs["tid"]
        msg.bid = msg_hs["bid"]
        msg.rid = msg_hs["rid"]
        msg.deadline = msg_hs["dl"]
        msg.sendtime = msg_hs["st"]
        msg.v = version
        msg
      end
    end
  end
end
