module Broker
  class Worker
    NL = "\n".freeze
    OK = "ok".freeze
    NOT_FOUND = "not_found".freeze

    attr_reader :url, :timeout
    attr_accessor :reconnect

    def initialize(opts = {})
      @timeout   = opts[:timeout] || 5.0
      @sock      = nil
      @url       = parse_url(opts[:broker_url] || "broker://127.0.0.1:6636")
      @reconnect = opts[:reconnect] != false
      connect
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
