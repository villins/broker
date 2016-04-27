require 'json'
module Broker
  class Message
    attr_accessor :code, :data, :from, :action, :service, :nav 

    def initialize(options)
      @code = options.fetch(:code, "") 
      @data = options.fetch(:data, "") 
      @from = options.fetch(:from, "") 
      @action = options.fetch(:action, "") 
      @service = options.fetch(:service, "") 
      @nav = options.fetch(:nav, "") 
    end

    def to_json
      hash = {
        service: service,
        action: action,
        data: data,
        from: from,
        nav: nav
      }
      hash[:code] = code if action == "res"
      JSON.generate(hash)
    end

    def response
      @action = "res"
      self
    end

    def request
      @action = "req"
      self
    end

    def self.generate(json_string)
      Message.new(JSON.parse(json_string,:symbolize_names => true))
    end
  end
end
