module Broker
  class Message
    attr_reader :data 

    def initialize(options)
      data = options 
    end

    def code
      data[:code]
    end

    def data
      data[:data]
    end

    def form
      data[:form]
    end

    def action
      data[:action]
    end

    def action
      data[:service]
    end

    def nav
      data[:nav]
    end

    def to_json
      data.to_json
    end

    def build_res
      data[:action] = "rep"
    end

    def self.generate(json_string)
      Message.new(JSON.parse(json_string,:symbolize_names => true))
    end
  end
end
