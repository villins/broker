require_relative 'helper'

class TestWorker < Minitest::Test
  class MockWorker < Broker::Worker
    attr_accessor :process_times, :error_number, :has_raise

    def process
      sleep 0.01
      @process_times = @process_times.to_i + 1
      if @process_times == @error_number
        @has_raise = true
        raise "error on #{@error_number}"
      end
    end
  end

  def setup
    @manager = Broker::configure
    @worker = MockWorker.new(@manager)
    @worker.error_number = 0
    @worker.has_raise = false
    @worker.process_times = 0
  end

  def test_it
    @worker.error_number = 2
    t = Thread.new {
      @worker.run
    }
    sleep 0.05
    @manager.shutdown
    t.join
    assert @worker.has_raise === true
    assert_in_delta 5, @worker.process_times, 1
  end
end
