require 'json'
module Broker
  class Message
    attr_accessor :code, :data, :from, :action, :service, :nav

    # def initialize(options)
    #   @code = options.fetch(:code, "")
    #   @data = options.fetch(:data, "")
    #   @from = options.fetch(:from, "")
    #   @action = options.fetch(:action, "")
    #   @service = options.fetch(:service, "")
    #   @nav = options.fetch(:nav, "")
    # end

    def encode_data
      if @data != nil && @data != ""
        return (JSON.generate(@data) rescue @data.to_s)
      end
      return ""
    end

    def decode_data(data_enc)
      if data_enc and data_enc != ""
        @data = JSON.parse(data_enc) rescue data_enc
      end
    end

    def to_res
      res = [@action]
      case @action
      when "req_recv"
        res.concat [@service, @nav, encode_data, @from]
      when "req_send", "job_send"
        res.concat [@service, @nav, encode_data]
      when "res_send"
        res.concat [@code, encode_data, @from]
      when "res_recv"
        res.concat [@code, encode_data]
      when "err"
        res << @data.to_s
      end
      res
    end

    def to_s
      to_res.join(",")
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

    # def self.generate(json_string)
    #   Message.new(JSON.parse(json_string,:symbolize_names => true))
    # end

    def self.from_res(res)
      msg = Message.new
      msg.action = res[0]

      case msg.action
      when "req_recv"
        msg.service = res[1]
        msg.nav = res[2]
        msg.decode_data(res[3])
        msg.from = res[4]
      when "res_recv"
        msg.code = res[1].to_i
        msg.decode_data(res[2])
      when "err"
        msg.code = "500"
        msg.data = res[1]
      end
      msg
    end
  end
end
