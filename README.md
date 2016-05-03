# Broker

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'broker', git: "git@github.com:villins/broker.git"

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

## 在 rails 使用 yell 做日志切割
    ```
    # 添加gem
    gem 'yell-rails'

    # 更改日志配置
    Broker::Logging.logger = Yell.new do |l|
      l.level = 'gte.info'
      l.adapter :datefile, "#{Rails.root.join("log", "sidekiq.log")}", level: 'lte.error', keep: 5
      l.adapter :datefile, "#{Rails.root.join("log", "error.log")}", level: 'gte.error', keep: 5
    end
    ```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/broker/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
