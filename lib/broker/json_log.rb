module Broker
  module JsonLog
    extend self
    def new_by_file(name, fname, level=:debug)
       return new_by_console(name, level) if fname.nil?
       new_log(name, level) { |l|
         Logging.appenders.rolling_file(
          fname,
          :age => 'daily',
          :roll_by => 'date',
          :keep => '7',
          :layout => Logging.layouts.json(default_layout_opts)
         )
         l.add_appenders fname
       }
    end

    def new_by_console(name, level=:debug)
      new_log(name, level) { |l|
        Logging.appenders.stdout(
         :layout => Logging.layouts.json(default_layout_opts)
        )
        l.add_appenders 'stdout'
      }
    end

    def new_log(name, level, &block)
      log = Logging.logger[name]
      log.level = level
      block.call(log) if block
      log
    end

    def default_layout_opts
      {items: %w[timestamp level logger message pid]}
    end

  end
end
