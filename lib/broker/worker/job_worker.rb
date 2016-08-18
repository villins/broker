module Broker
  class JobWorker < Broker::Worker
    def process
      tubes = @manager.worker_map.keys

      begin
        @manager.beans.with {|conn|
          conn.tubes.watch(*tubes)

          begin
            job = conn.tubes.reserve(@manager.conf.pop_timeout)
            process_job(job)
          rescue Beaneater::JobNotReserved, Beaneater::NotFoundError, Beaneater::TimedOutError
            false
          end
        }
      rescue => err
        @logger.error(err)
        sleep(@manager.conf.pop_timeout) if BeanPool.is_conn_err(err)
        false
      end

    end

    def process_job(job)
      return false if job.nil?
      wrk = @manager.get_worker(job.tube)
      if wrk.nil?
        @logger.warn("unfound work with tube: #{job.tube}")
        return false
      end

      msg = @manager.unpack(job.body)

      # traceid
      Message.trace msg.traceid

      begin
        wrk.work(msg.data)
        job.delete
      rescue => err
        @logger.error(err)
        job.bury
        return false
      end
      return true
    end
  end
end
