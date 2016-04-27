require 'bundler/setup'
Bundler.setup
require 'broker'

Broker.configure do |config|
  config.url = "broker://127.0.0.1:6636"
end

Broker.sync_config_handle do |flag, info|
  puts "配置同步没做处理"
end

Broker.on("users/create") do |res, rsp|
    puts res
end

Broker.run("dev")
