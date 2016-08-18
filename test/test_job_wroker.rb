require_relative 'helper'

class TestJobWorker < Minitest::Test
  def setup
    @manager = Broker::configure
    @worker = Broker::JobWorker.new(@manager)
  end


end
