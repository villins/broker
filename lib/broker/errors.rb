module Broker
  Error           = Class.new(RuntimeError)
  BrokerUninitialized = Class.new(Error)
  ProtocolError   = Class.new(Error)
  ArgumentError   = Class.new(Error)
end
