require_relative 'helper'

class TestSignal < Minitest::Test
  def test_default_lock
    arr = []
    (0..2).map {|i|
      Thread.new {
        Broker::SignalSync.lock(:unfoud) {
          sleep 0.1
          arr << Time.now.to_f
        }
      }
    }.each {|t| t.join }

    min = arr.min
    sum = 0
    arr.each {|v| sum += v}
    assert_in_delta(min, sum/arr.length, 0.33/3)
  end

  def test_multi_lock
    arr = []
    Broker::SignalSync.add_locker(:a, :b)

    #unfound and c => 0.11
    #a => 0.11
    #b => 0.11
    [:unfound, :a,:b, :a,:b, :c].map {|kind|
      Thread.new {
        Broker::SignalSync.lock(kind) {
          sleep 0.1
          arr << Time.now.to_f
        }
      }
    }.each {|t| t.join }

    min = arr.min
    sum = 0
    arr.each {|v| sum += v}
    assert_in_delta(min, sum/arr.length, 0.33/6)
  end

  def test_waiter_noblock
    waiter = Broker::SignalSync.waiter
    waiter2 = Broker::SignalSync.waiter
    # 保持：1/线程
    assert_equal waiter, waiter2

    [0.1,0.3].each do |secs|
      Thread.new {
        sleep secs
        waiter.signal
      }
    end

    start_at = Time.now.to_f
    2.times do |i|
      waiter.wait
    end
    end_at = Time.now.to_f

    assert_in_delta start_at, end_at, 0.31
  end

  def test_waiter_notimeout
    waiter = Broker::SignalSync.waiter

    [0.1,0.3].each do |secs|
      Thread.new {
        sleep secs
        waiter.signal secs
      }
    end

    start_at = Time.now.to_f
    datas = []
    2.times do |i|
      waiter.wait { |evt, data|
        datas << data if evt == :after && data
      }
    end
    end_at = Time.now.to_f

    assert_in_delta start_at, end_at, 0.31
    assert_equal 2, datas.length

  end

  def test_waiter_timeout
    waiter = Broker::SignalSync.waiter
    ts = [0.1,0.3].map do |secs|
      Thread.new {
        sleep secs
        waiter.signal secs
      }
    end
    start_at = Time.now.to_f
    datas = []
    2.times do |i|
      waiter.wait(0.11) { |evt, data|
        datas << data if evt == :after && data
      }
    end
    end_at = Time.now.to_f
    ts.each {|t| t.join }
    assert_in_delta start_at, end_at, 0.22
    assert_equal 1, datas.length
  end
end
