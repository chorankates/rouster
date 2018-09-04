

class Rouster
  ##
  # get_crontab
  #
  # runs `crontab -l <user>` and parses output, returns hash:
  # {
  #   user => {
  #     command => {
  #       :minute => minute,
  #       :hour   => hour,
  #       :dom    => dom, # day of month
  #       :mon    => mon, # month
  #       :dow    => dow, # day of week
  #     }
  #   }
  # }
  #
  # the hash will contain integers (not strings) for numerical values -- all but '*'
  #
  # parameters
  # * <user> - name of user who owns crontab for examination -- or '*' to determine list of users and iterate over them to find all cron jobs
  # * [cache] - boolean controlling whether or not retrieved/parsed data is cached, defaults to true
  # * [seed]  - test hook to seed the output of crontab commands
  def get_crontab(user='root', cache=true, seed=nil)

    if cache and self.deltas[:crontab].class.eql?(Hash)

      if self.cache_timeout and self.cache_timeout.is_a?(Integer) and (Time.now.to_i - self.cache[:crontab]) > self.cache_timeout
        @logger.debug(sprintf('invalidating [crontab] cache, was [%s] old, allowed [%s]', (Time.now.to_i - self.cache[:crontab]), self.cache_timeout))
        self.deltas.delete(:crontab)
      end

      if self.deltas.has_key?(:crontab) and self.deltas[:crontab].has_key?(user)
        @logger.debug(sprintf('using cached [crontab] from [%s]', self.cache[:crontab]))
        return self.deltas[:crontab][user]
      elsif self.deltas.has_key?(:crontab) and user.eql?('*')
        @logger.debug(sprintf('using cached [crontab] from [%s]', self.cache[:crontab]))
        return self.deltas[:crontab]
      else
        # noop fallthrough to gather data to cache
      end

    end

    res = Hash.new
    users = nil

    if user.eql?('*')
      users = self.get_users().keys
    else
      users = [user]
    end

    users.each do |u|
      begin
        raw = self.run(sprintf('crontab -u %s -l', u))
      rescue RemoteExecutionError => e
        # crontab throws a non-0 exit code if there is no crontab for the specified user
        res[u] ||= Hash.new
        next
      end

      raw.split("\n").each do |line|
        next if line.match(/^#|^\s+$/)
        elements = line.split("\s")

        if elements.size < 5
          # this is usually (only?) caused by ENV_VARIABLE=VALUE directives
          @logger.debug(sprintf('line [%s] did not match format expectations for a crontab entry, skipping', line))
          next
        end

        command = elements[5..elements.size].join(' ')

        res[u] ||= Hash.new

        if res[u][command].class.eql?(Hash)
          unique = elements.join('')
          command = sprintf('%s-duplicate.%s', command, unique)
          @logger.info(sprintf('duplicate crontab command found, adding hash key[%s]', command))
        end

        res[u][command]           = Hash.new
        res[u][command][:minute]  = elements[0]
        res[u][command][:hour]    = elements[1]
        res[u][command][:dom]     = elements[2]
        res[u][command][:mon]     = elements[3]
        res[u][command][:dow]     = elements[4]
      end
    end

    if cache
      @logger.debug(sprintf('caching [crontab] at [%s]', Time.now.asctime))

      if ! user.eql?('*')
        self.deltas[:crontab] ||= Hash.new
        self.deltas[:crontab][user] ||= Hash.new
        self.deltas[:crontab][user] = res[user]
      else
        self.deltas[:crontab] ||= Hash.new
        self.deltas[:crontab] = res
      end

      self.cache[:crontab] = Time.now.to_i

    end

    return user.eql?('*') ? res : res[user]
  end

end