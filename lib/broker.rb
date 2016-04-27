require "broker/version"
require "connection_pool"
require "broker/logging"
require "broker/errors"
require "broker/message"
require "broker/worker"
require "broker/cli"

module Broker
  def self.configure
    yield server.configuration
    unless server.configuration.pool_work_size?
      Broker::Logging.logger.error("pool_size must be gt worker_pool_size")
    end
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

  def self.server
    @server ||= Broker::Cli.new
  end

  def self.request(topic, data = {})
    server.request(topic, data)
  end

  def self.run(name)
    server.run
  end
end

