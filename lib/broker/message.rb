require 'json'
module Broker
  class Message
    attr_accessor :code, :data, :from, :action, :service, :nav

    def to_res
      cmds = [@action]
      case @action
      when "req_recv"
        cmds.concat [@service, @nav, @from]
      when "req_send", "job_send"
        cmds.concat [@service, @nav]
      when "res_send"
        cmds.concat [@code, @from]
      when "res_recv"
        cmds.concat [@code]
      when "err"
        cmds << @data.to_s
        @data = nil
      end
      return [cmds, @data]
    end

    def code=(v)
      @code = v.to_s
    end

    def from=(v)
      @from = v.to_s
    end

    def nav=(v)
      @nav = v.to_s
    end

    def service=(v)
      @service = v.to_s
    end

    def res_success?
      code == "0" || code == "302"
    end

    def to_s
      cmds, data = to_res
      return "cmds:#{cmds.join(',')} ; data: #{data}"
    end

    def response
      @action = "res_send"
      @code = "0"
      @data = {}
      self
    end

    def request
      @action = "req_send"
      self
    end

    def self.from_res(cmds, data=nil)
      msg = Message.new
      msg.action = cmds[0]

      case msg.action
      when "req_recv"
        msg.service = cmds[1]
        msg.nav = cmds[2]
        msg.from = cmds[3]
        msg.data = data
      when "res_recv"
        msg.code = cmds[1]
        msg.data = data
      when "err"
        msg.code = "500"
        msg.data = cmds[1]
      end
      msg
    end
  end
end
