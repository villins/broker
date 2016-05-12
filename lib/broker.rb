require 'msgpack'
require "broker/version"
require "connection_pool"
require "broker/logging"
require "broker/errors"
require "broker/message"
require "broker/worker"
require "broker/cli"
require 'broker/beanstalk_hack'



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

  def self.job(topic, &block)
    server.job(topic, &block)
  end

  def self.server
    @server ||= Broker::Cli.new
  end

  def self.request(topic, data = {}, nav="")
    server.request(topic, data, nav)
  end

  def self.put(tube, data={}, nav="")
    server.put(tube, data, nav)
  end

  def self.run(name)
    server.run name
  end
end
