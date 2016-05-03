require "beaneater"
# hack，当beanstalkd重启时，虽然client能重连，但是订阅的tube信息已经丢失
# 所以需要重新链接
class Beaneater
  class Jobs
    def process!(options={})
      release_delay = options.delete(:release_delay) || RELEASE_DELAY
      reserve_timeout = options.delete(:reserve_timeout) || RESERVE_TIMEOUT
      client.tubes.watch!(*processors.keys)
      while !stop? do
        begin
          @current_job = client.tubes.reserve(reserve_timeout)
          processor = processors[@current_job.tube]
          begin
            processor[:block].call(@current_job)
            @current_job.delete
          rescue *processor[:retry_on]
            if @current_job.stats.releases < processor[:max_retries]
              @current_job.release(:delay => release_delay)
            end
          end
        rescue AbortProcessingError
          break
        rescue Beaneater::JobNotReserved, Beaneater::NotFoundError, Beaneater::TimedOutError
          retry
        rescue Beaneater::NotConnected,EOFError, Errno::ECONNRESET, Errno::EPIPE,
      Errno::ECONNREFUSED
          raise  # 若链接已经断开，则抛出错误
        rescue StandardError # handles unspecified errors
          @current_job.bury if @current_job
        ensure # bury if still reserved
          @current_job.bury if @current_job && @current_job.exists? && @current_job.reserved?
          @current_job = nil
        end
      end
    end # process!
  end
end
