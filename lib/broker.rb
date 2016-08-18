require 'msgpack'
require 'oj'
require 'thread'
require 'logging'
require_relative "broker/version"
require_relative "broker/errors"
require_relative "broker/signal"
require_relative "broker/pool"
require_relative "broker/redis_pool"
require_relative "broker/bean_pool"
require_relative "broker/json_log"
require_relative "broker/message"
require_relative "broker/manager"
require_relative "broker/worker"
require_relative "broker/worker/inbox_worker"
require_relative "broker/worker/job_worker"

Oj.default_options = {:symbol_keys => false, :mode => :compat}
MultiJson.use :oj

module Broker
  extend self
  @@manager = nil

  def method_missing(name, *args, &block)
    raise BrokerUninitialized if @@manager.nil?
    @@manager.send(name, *args, &block)
  end

  def configure(&block)
    conf = Config.new
    block.call conf if block
    @@manager = Manager.instance(conf)
  end

  def start_server(*args)
    @@manager.start_server
  end
  alias_method :run, :start_server

  # discard
  def sync_config_handle(&block)
    @@manager
  end
end
