

class Rouster
  ##
  # get_ports
  #
  # runs an OS appropriate command to gather port information, returns hash:
  # {
  #   protocolN => {
  #     portN => {
  #       :addressN => state
  #     }
  #   }
  # }
  #
  # parameters
  # * [cache] - boolean controlling whether data retrieved/parsed is cached, defaults to true
  #
  # supported OS
  # * RedHat, Ubuntu - runs `netstat -ln`
  #
  # raises InternalError if unsupported operating system
  def get_ports(cache=false)
    # TODO add unix domain sockets
    # TODO improve ipv6 support

    if cache and ! self.deltas[:ports].nil?
      if self.cache_timeout and self.cache_timeout.is_a?(Integer) and (Time.now.to_i - self.cache[:ports]) > self.cache_timeout
        @logger.debug(sprintf('invalidating [ports] cache, was [%s] old, allowed [%s]', (Time.now.to_i - self.cache[:ports]), self.cache_timeout))
        self.deltas.delete(:ports)
      else
        @logger.debug(sprintf('using cached [ports] from [%s]', self.cache[:ports]))
        return self.deltas[:ports]
      end
    end

    res = Hash.new()
    os  = self.os_type()

    if os.eql?(:rhel) or os.eql?(:ubuntu) or os.eql?(:debian)

      raw = self.run('netstat -ln')

      raw.split("\n").each do |line|

        next unless line.match(/(\w+)\s+\d+\s+\d+\s+([\S\:]*)\:(\w*)\s.*?(\w+)\s/) or line.match(/(\w+)\s+\d+\s+\d+\s+([\S\:]*)\:(\w*)\s.*?(\w*)\s/)

        protocol = $1
        address  = $2
        port     = $3
        state    = protocol.eql?('udp') ? 'you_might_not_get_it' : $4

        res[protocol] = Hash.new if res[protocol].nil?
        res[protocol][port] = Hash.new if res[protocol][port].nil?
        res[protocol][port][:address] = Hash.new if res[protocol][port][:address].nil?
        res[protocol][port][:address][address] = state

      end
    else
      raise InternalError.new(sprintf('unable to get port information from VM operating system[%s]', os))
    end

    if cache
      @logger.debug(sprintf('caching [ports] at [%s]', Time.now.asctime))
      self.deltas[:ports] = res
      self.cache[:ports]  = Time.now.to_i
    end

    res
  end
end