module Broker
  class InboxWorker < Broker::Worker
    def process
      result = @manager.redis.exec(:blpop, @manager.inboxs, :timeout => @manager.conf.pop_timeout)
      return false if result.nil?
      if result.is_a? RuntimeError
        logger.error("redis blpop fail: #{result.class} | #{result.to_s}")
        sleep @manager.conf.pop_timeout
        return false
      end

      msg_bytes = result[1]
      msg = @manager.unpack(msg_bytes)

      case msg.action
      when "req"
        process_req msg
      when "res"
        process_res msg
      else
        raise ProtocolError.new("wrong action: #{msg.action}")
      end
      msg.action
    end

    def process_req(msg_req)
      Message.trace msg_req.traceid

      msg_res = msg_req.to_res

      service = @manager.get_service(msg_req.topic, msg_req.channel)
      if service.nil?
        msg_res.code = "400"
        msg_res.data = "unfound service: #{msg_req.topic}/#{msg_req.channel}"
      else
        begin
          service.process(msg_req, msg_res)
        rescue => err
          msg_res.code = "500"
          msg_res.data = "#{err.class} | #{err.to_s}"
          logger.error(err)
        end

      end

      msg_bytes = @manager.pack(msg_res)
      @manager.redis.exec :rpush, @manager.outbox(msg_req), msg_bytes
    end

    def process_res(msg_res)
      @manager.response(msg_res)
    end
  end
end
