require 'bundler/setup'
Bundler.setup
require 'broker'

rep = Broker.request("users/create")
puts rep
