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
     Broker.configure do |config|
       config.redis_url = "redis://127.0.0.1:6379"
       config.service_worker_size = 10
       # job beanstalk
       # config.job_worker_size = 2
       # config.job_server_url = "127.0.0.1:11300"
       config.node_name = "auth_client"
       # config.log_file = "#{Rails.root}/log/#{self.name}.log"
       # config.log_level = :debug
     end


     ### 添加 service 路由
     Broker.on("users/create") do |res, rsp|
       puts res
     end

     ### 添加 job 路由
     Broker.job("user-email-notify") do |job|
      puts job
     end

     ### 启动服务
     Broker.run
    ```


## Contributing

1. Fork it ( https://github.com/[my-github-username]/broker/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
