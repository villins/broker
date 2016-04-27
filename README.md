# Broker

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'broker', git: "git@github.com/villins/broker.git"

And then execute:

    $ bundle

## Usage
> 具体看 example 目录例子

    ```
     ### 配置
     ### broker_url, pool_size, worker_pool_size, timeout, timer_interval
     Broker.configure do |config|
       config.broker_url = "broker://127.0.0.1:6636"
     end

     ### 配置同步block
     Broker.sync_config_handle do |flag, info|
       puts "配置同步没做处理"
     end

     ### 添加 service 路由
     Broker.on("users/create") do |res, rsp|
       puts res
     end

     ### 启动服务
     Broker.run("users")
    ```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/broker/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
