require "broker/version"
require "connection_pool"
require "broker/errors"
require "broker/message"
require "broker/worker"
require "broker/cli"

module Broker
  def self.configure
    yield server.configuration
  end

  def self.configuration
    server.configuration
  end

  def self.service
    configuration.service
  end

  def self.sync_config_handle(&block)
    server.sync_config(block) if block_given?
  end

  def self.on(topic, &block)
    server.subscribe(topic, &block)
  end

  def self.routes
    yield
  end

  def self.server
    @server ||= Broker::Cli.new("auth")
  end

  def self.request(topic, data = {})
    server.request(topic, data)
  end

  def self.run(name)
    server.run
  end
end

