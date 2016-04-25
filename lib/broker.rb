require "broker/version"
require "connection_pool"

module Broker
  def self.configure
    yield self if server?
  end

  def self.config=(hash)
    @config = hash
  end

  def self.service
    @config[:service]
  end

  def self.server?
    defined?(Broker::Cli)
  end

  def self.sync_handle
    @sync_handle = block if block_given?
  end

  def self.sub(action, &block)
    @routes ||= {}
    @routes[action] ||= []
    @routes[action].push(block)
  end

  def self.routes
    @routes
  end

  def self.services
    routes.keys
  end

  def self.broker_pool
    @broker_pool ||= ConnectionPool.new(size: config[:pool_size], timeout: config[:timeout]) do
      ::Client.new(config).connect
    end
  end

  def self.run(name)
  end
end

