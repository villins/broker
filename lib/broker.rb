require "broker/version"
require "connection_pool"
require "broker/errors"
require "broker/message"
require "broker/worker"
require "broker/cli"

module Broker
  def self.configure
    yield config if server?
  end

  def self.config
    server.configuration
  end

  def self.service
    @config[:service]
  end

  def self.sync_handle
    server.sync(block) if block_given?
  end

  def self.on(action, &block)
    server.subscribe(action, block)
  end

  def self.server
    @server ||= Broker::Cli.new(service)
  end

  def self.run(name)
    @server.run
  end
end

