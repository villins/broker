module Broker
  class Client
    NL = "\n".freeze
    OK = "ok".freeze
    NOT_FOUND = "not_found".freeze

    attr_reader :url, :timeout
    attr_accessor :reconnect

    def initialize(opts = {})
      @timeout   = opts[:timeout] || 5.0
      @sock      = nil
      @url       = parse_url(opts[:url] || ENV["BROKER_URL"])
      @reconnect = opts[:reconnect] != false
    end

    def parse_url(url)
      url = URI(url) if url.is_a?(String)

      # Validate URL
      unless url.host
        raise ArgumentError, "Invalid :url option, unable to determine 'host'."
      end
      url
    end

    def port
      @port ||= url.port || 6380
    end

    def sock_timeout
      @sock_timeout ||= begin
        secs  = Integer(timeout)
        usecs = Integer((timeout - secs) * 1_000_000)
        [secs, usecs].pack("l_2")
      end
    end

    def connect
      addr = Socket.getaddrinfo(url.host, nil)
      @sock = Socket.new(Socket.const_get(addr[0][0]), Socket::SOCK_STREAM, 0)
      @sock.setsockopt Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, sock_timeout
      @sock.setsockopt Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, sock_timeout
      @sock.connect(Socket.pack_sockaddr_in(port, addr[0][3]))
      self
    end

    # @return [Boolean] true if connected
    def connected?
      !!@sock
    end

    # Disconnects the client
    def disconnect
        @sock.close if connected?
      rescue
      ensure
        @sock = nil
    end

    # Safely perform IO operation
    def io(op, *args)
      @sock.__send__(op, *args)
    rescue Errno::EAGAIN
      raise Broker::TimeoutError, "Connection timed out"
    rescue Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNABORTED, Errno::EBADF, Errno::EINVAL => e
      if @reconnect
        disconnect
        connect
      end
      raise Broker::ConnectionError, "Connection lost (%s)" % [e.class.name.split("::").last]
    end

    def exec(cmds)
      data = ""
      cmds.each do |cmd|
        cmd = cmd.to_s
        data << cmd.bytesize.to_s << NL << cmd << NL
      end
      data << NL

      send_data data
      recv_data
    end

    def hgetall(table, result_type = :dict, &decode)
      result = exec ["hgetall", table]
      ok = _ok? result

      case result_type
        when :list then
          return _dict_list(result, &decode)
        else
          return _dict(result, &decode)
      end
    end

    def hset_multi(table, data, &encode)
      if data.is_a?(Hash)
        kvs = data.map { |k, v| [k, encode ? encode.call(v) : v] }.flatten
      elsif data.is_a?(Array)
        kvs = []
        data.each_slice(2) { |k, v|
          kvs << k
          kvs << (encode ? encode.call(v) : v)
        }
      end

      result = exec (["multi_hset", table] + kvs)
      _ok? result
    end

    def hget(table, key, &decode)
      result = exec ["hget", table, key]
      if _ok? result
        decode ? decode.call(result[1]) : result[1]
      else
        nil
      end
    end

    def hset(table, key, data, &encode)
      data = encode.call(data) if encode
      result = exec ["hset", table, key, data]
      _ok? result
    end

    def hdel(table, key)
      exec ["hdel", table, key]
    end

    def multi_hdel(table, keys)
      result = exec ["multi_hdel", table].concat(keys)
    end

    def get(key, &decode)
      result = exec ["get", key]
      if _ok? result
        decode ? decode.call(result[1]) : result[1]
      else
        nil
      end
    end

    def set(key, data, ttl=0,  &encode)
      data = encode.call(data) if encode

      if ttl > 0
        exec ["setx", key, data, ttl]
      else
        exec ["set", key, data]
      end
    end

    def del(key)
      exec ["del", key]
    end

    def qback key
      exec ['qback', key]
    end

    def qpop(key, size, &decode)
      items = exec ['qpop', key, size]
      _list(items, &decode)
    end

    def qpush(key, data)
      exec ['qpush', key, data]
    end

    def qrange(key, start_index, end_index)
      items = exec ['qrange', key, start_index, end_index]
      _list(items)
    end

    def hscan(key,key_start,key_end,limit)
      exec ['hscan', key, key_start, key_end, limit]
    end

    def incr(key)
      exec ['incr', key]
    end

    def expire(key,seconds)
      exec ['expire', key, seconds]
    end

    def _ok?(items)
      items[0] == "ok"
    end

    def _dict(items, &decode)
      result = Hash.new
      if _ok?(items)
        items[1..-1].each_slice(2) do |field, value|
          result[field] = decode ? decode.call(value) : value
        end
      end
      result
    end

    def _dict_list(items, &decode)
      _dict(items, &decode).values
    end

    def _list(items, &decode)
      result = []
      if _ok?(items)
        items = items[1..-1]
        if decode
          result = items.map do |item|
            decode.call(item)
          end
        else
          result = items
        end
      end
      result
    end

    def send_data(data)
      io(:write, data)
    end

    def recv_data
      state = :size
      data = []
      size = 0
      prefix = ""

      while true
        case state
        when :size # read size block
          size = (prefix + io(:gets)).chomp.to_i
          state = :data
        when :data # read data block
          s = io(:read, size + 2)
          prefix = s[-1]
          if prefix == NL # end
            prefix = ""
            data.push s[0, size]
            return data
          else # data
            data.push s[0, size]
            state = :size
          end
        end
      end
    end
  end
end
