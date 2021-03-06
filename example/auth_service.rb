require 'bundler/setup'
Bundler.setup
require 'broker'

Broker.configure do |config|
  config.redis_url = "redis://127.0.0.1:6379"
  config.service_worker_size = 2
  # config.job_worker_size = 2
  config.node_name = "auth_service"
  # config.log_file = "#{Rails.root}/log/#{self.name}.log"
  # config.log_level = :debug
end

Broker.on("users/create") do |req, res|
  res.data = "ok"
end

Broker.run
