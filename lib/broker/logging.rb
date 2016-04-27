require 'logger'

module Broker
  module Logging
    def self.init_logger(log_target = STDOUT)
      old_logger = defined?(@logger) ? @logger : nil
      old_logger.close if old_logger

      @logger = Logger.new(log_target)
      @logger.level = Logger::INFO
      @logger.formatter = proc do |level, datetime, progname, msg| 
        date_format = datetime.strftime("%Y-%m-%d %H:%M:%S")
        "[#{ date_format }] #{ level.ljust(5) } (#{ progname }) : #{ msg } \n"
      end
      @logger
    end

    def self.logger
      defined?(@logger) ? @logger : init_logger
    end

    def self.logger=(log)
      @logger = (log ? log : Logger.new(File::NULL))
    end

    def logger
      Broker::Logging.logger
    end
  end
end
