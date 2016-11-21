## Broker

为了可维护性，把可独立复用的服务拆分出来，通过协定的RPC（后续说明）对外提供服务。

该项目为 ruby 提供的 Client/Server 等接入方式。


## 消息流转机制

```
Client 按协议接入的客户端
Server 按协议接入的服务端
MicroBroker 消息搬运工(https://github.com/chashu-code/micro-broker)
MSG 带版本的消息数据包（类型：request/response/job）

     <------ pull job --------------------------------------------------------
    |                                                                         |
    |<------ pull request -----------                                         |
    |                                |                                        |
Server --- push response --------->  |                                        |
                                   | |                                        |
                                   | |                                        |
Client --- push request/job --->  Redis --- pull MSG ---> MicroBroker    beanstalk
   |                               | |                     |  |               |
    <--- pull pid response --------   <--- route MSG ------    -- route job -->

```

## 架构说明

因时间仓促，考虑到接入的项目语言多样性，以及MicroBroker的成熟度不足，可能会频繁修复升级，所以在满足性能要求的前提下（长连接），能够让各语言服务项目快速可靠地接入（成熟库），不受MicroBroker的短暂升级影响（只做间接的目标搬运），引入Redis作为消息队列缓冲。


## API

### res = Broker.requestx(args={})

仅接受hash args的request，并返回响应信息

**args 的属性：**

* action => 行为 req/job/res
* topic => 服务或任务主题
* channel => 主题下的子频道，可选
* nav => 一般不提供，用于micro-broker 做负载均衡的计算参数
* timeout => 超时秒数，默认3s
* data => 消息内容，hash/number/string/boolean

**响应信息 res 的 属性：**

* code 响应码，0 为正常，其余异常
* data 响应结果内容
* traceid 追溯id，从最初的请求开始，知道获得回应，哪怕中间经过N个其余请求，都保持同样的traceid
* rid 请求id
* v 版本号


...

### res = Broker.request(service, args, nav=nil, timeout_secs=3)

推送请求，等价于：

```
topic, channel = service.split("/", 2)
Broker.requestx({
  action: 'req',
  topic: topic,
  channel: channel,
  timeout: timeout_secs,
  data: args
  nav: nav
})
```

### res = Broker.put(tube, args, nav=nil, timeout_secs=3)
推送任务，等价于：
```
Broker.requestx({
  action: 'job',
  topic: tube,
  timeout: timeout_secs,
  data: args
  nav: nav
})
```

### Broker.on(service, &block)
服务订阅处理

```
service = [topic, channel].join("/")

Broker.on(service) do |req, res|
  req.data # 读取参数

  if req.data["name"] == "rb"
    res.data = "hello ruby"
  else
    res.code = '533'
    res.data = '错误信息……'
  end
end
```

### Broker.job(tube, &block)
任务订阅处理

```
Broker.job("background-job") do |data|
  data # job.data
end
```


## Client example

### rails setup

**Gemfile**
```
gem 'broker', git: "https://github.com/villins/broker.git"
```

**lib/broker_setup.rb**
```
# Broker 配置
Broker.configure do |config|
  # 链接的Redis URL
  config.redis_url = "redis://127.0.0.1:6379"
  # 需要拉取消息的工作线程数
  config.service_worker_size = 10
  # 日志区分用
  config.node_name = "op-alliance-show"
  # 日志的文件及过滤
  config.log_file = "#{Rails.root}/log/broker.log" #
  config.log_level = (Rails.env == "production" ? :info : :debug)
  # 是否禁止接受终端 Ctrl + C 等信号
  config.disable_signal = true
end

# 替换 rails 默认日志
Rails.logger = Broker.logger

# 新的线程运行
Thread.new {
  Broker.run
}
```

**config/puma.rb**

此为puma载入配置，其它框架类似
```
# 在进程启动时，让Broker跑起来
on_worker_boot do
  require_relative "../lib/broker_setup"
end

```

### controller action use

**app/controllers/api_controller.rb**
```
class ApiController < ActionController::Base
  def send_req
    service_path = 'service/path/..'
    args = {
      arg1: 'xxx',
      arg2: 333
    }
    # 调用远程服务
    res = Broker.request(service_path, args)

    if res.code == '0'
      render json: {code: '0', msg: "成功了~"}
    else
      # 输出错误信息
      render json: {code: res.code, msg: res.data}
    end
  end

  def send_job
    job_tube = 'job-tube'
    args = {
      arg1: 1,
      arg2: 'xxx'
    }
    res = Broker.put(job_tube, args)
    # 和 send_req 一样的判断
  end
end
```

## Server example

**lib/broker_setup.rb**
```
Broker.configure do |config|
   config.redis_url = "redis://127.0.0.1:6379"
   config.service_worker_size = 10
   # 任务订阅工作线程数
   config.job_worker_size = 2
   config.node_name = self.name
   config.log_file = "#{Rails.root}/log/broker.log"
   config.log_level = (Rails.env == "production" ? :info : :debug)
end

# 服务请求路由
Broker.on("xxxx") do |req, res|
   # 自定义的处理模块
  XXXModule.process(req, res)
end

# 任务推送路由
Broker.job("xxx") |job_data|
  # 自定义的处理模块
  XXXWorker.process(job_data)
end
```

**lib/tasks/broker_service.rake**
```
require ::File.expand_path('../../../config/environment', __FILE__)
require ::File.expand_path('../../../lib/broker_setup', __FILE__)
Rails.application.eager_load!


namespace :broker_service do
  task :start => :environment do
    Rake::Task["broker_service:stop"].invoke
    IO.write "server.pid", Process.pid
    Broker.run
  end

  task :stop do
    service_pid = "service.pid"
    if File.exist? service_pid
      `kill -9 $(cat #{service_pid})`
    end
  end
end
```

**终端项目根目录执行**
```
nohup bundle exec rake broker_service:start RAILS_ENV="production" 1>>stdout.log 2>&1 &
```