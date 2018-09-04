

class Rouster
  ##
  # get_groups
  #
  # cats /etc/group and parses output, returns hash:
  # {
  #   groupN => {
  #     :gid => gid,
  #     :users => [user1, userN]
  #   }
  # }
  #
  # parameters
  # * [cache] - boolean controlling whether data retrieved/parsed is cached, defaults to true
  # * [deep]  - boolean controlling whether get_users() is called in order to correctly populate res[group][:users]
  # * [seed]  - test hook to seed the output to parse
  def get_groups(cache=true, deep=true, seed=nil)

    if cache and ! self.deltas[:groups].nil?

      if self.cache_timeout and self.cache_timeout.is_a?(Integer) and (Time.now.to_i - self.cache[:groups]) > self.cache_timeout
        @logger.debug(sprintf('invalidating [groups] cache, was [%s] old, allowed [%s]', (Time.now.to_i - self.cache[:groups]), self.cache_timeout))
        self.deltas.delete(:groups)
      else
        @logger.debug(sprintf('using cached [groups] from [%s]', self.cache[:groups]))
        return self.deltas[:groups]
      end

    end

    res = Hash.new()

    if seed.nil?
      raw = {
        :file    => self.run('cat /etc/group'),
        :dynamic => self.run('getent group', [0,127]),
      }
    else
      raw = {
        :seed => seed,
      }
    end

    raw.each_pair do |source, raw|

      raw.split("\n").each do |line|
        next unless line.match(/\w+:\w*:\w+/)

        data = line.split(':')

        group = data[0]
        gid   = data[2]

        # this works in some cases, deep functionality picks up the others
        users = data[3].nil? ? ['NONE'] : data[3].split(',')

        if res.has_key?(group)
          @logger.debug(sprintf('for[%s] old GID[%s] new GID[%s]', group, gid, res[group][:users])) unless gid.eql?(res[group][:gid])
          @logger.debug(sprintf('for[%s] old users[%s] new users[%s]', group, users)) unless users.eql?(res[group][:users])
        end

        res[group] = Hash.new() # i miss autovivification
        res[group][:gid]    = gid
        res[group][:users]  = users
        res[group][:source] = source
      end

    end

    groups = res

    if deep
      users = self.get_users(cache)

      known_valid_gids = groups.keys.map { |g| groups[g][:gid] } # no need to calculate this in every loop

      # TODO better, much better -- since the number of users/groups is finite and usually small, this is a low priority
      users.each_key do |user|
        # iterate over each user to get their gid
        gid = users[user][:gid]

        unless known_valid_gids.member?(gid)
          @logger.warn(sprintf('found user[%s] with unknown GID[%s], known GIDs[%s]', user, gid, known_valid_gids))
          next
        end

        ## do this more efficiently
        groups.each_key do |group|
          # iterate over each group to find the matching gid
          if gid.eql?(groups[group][:gid])
            if groups[group][:users].eql?(['NONE'])
              groups[group][:users] = []
            end
            groups[group][:users] << user unless groups[group][:users].member?(user)
          end

        end

      end
    end

    if cache
      @logger.debug(sprintf('caching [groups] at [%s]', Time.now.asctime))
      self.deltas[:groups] = groups
      self.cache[:groups]  = Time.now.to_i
    end

    groups
  end

end