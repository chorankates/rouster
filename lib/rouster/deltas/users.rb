

class Rouster
  ##
  # get_users
  #
  # cats /etc/passwd and parses output, returns hash:
  # {
  #   userN => {
  #     :gid => gid,
  #     :home  => path_of_homedir,
  #     :home_exists => boolean_of_is_dir?(:home),
  #     :shell => path_to_shell,
  #     :uid => uid
  #   }
  # }
  # parameters
  # * [cache] - boolean controlling whether data retrieved/parsed is cached, defaults to true
  def get_users(cache=true)
    if cache and ! self.deltas[:users].nil?

      if self.cache_timeout and self.cache_timeout.is_a?(Integer) and (Time.now.to_i - self.cache[:users]) > self.cache_timeout
        @logger.debug(sprintf('invalidating [users] cache, was [%s] old, allowed [%s]', (Time.now.to_i - self.cache[:users]), self.cache_timeout))
        self.deltas.delete(:users)
      else
        @logger.debug(sprintf('using cached [users] from [%s]', self.cache[:users]))
        return self.deltas[:users]
      end

    end

    res = Hash.new()

    {
        :file    => self.run('cat /etc/passwd'),
        :dynamic => self.run('getent passwd', [0,127]),
    }.each do |source, raw|

      raw.split("\n").each do |line|
        next if line.match(/([\w\.-]+)(?::\w+){3,}/).nil?

        user = $1
        data = line.split(':')

        shell       = data[-1]
        home        = data[-2]
        home_exists = self.is_dir?(data[-2])
        uid         = data[2]
        gid         = data[3]

        if res.has_key?(user)
          @logger.info(sprintf('for[%s] old shell[%s], new shell[%s]', user, res[user][:shell], shell)) unless shell.eql?(res[user][:shell])
          @logger.info(sprintf('for[%s] old home[%s], new home[%s]', user, res[user][:home], home)) unless home.eql?(res[user][:home])
          @logger.info(sprintf('for[%s] old home_exists[%s], new home_exists[%s]', user, res[user][:home_exists], home_exists)) unless home_exists.eql?(res[user][:home_exists])
          @logger.info(sprintf('for[%s] old UID[%s], new UID[%s]', user, res[user][:uid], uid)) unless uid.eql?(res[user][:uid])
          @logger.info(sprintf('for[%s] old GID[%s], new GID[%s]', user, res[user][:gid], gid)) unless gid.eql?(res[user][:gid])
        end

        res[user] = Hash.new()
        res[user][:shell]       = shell
        res[user][:home]        = home
        res[user][:home_exists] = home_exists
        res[user][:uid]         = uid
        res[user][:gid]         = gid
        res[user][:source]      = source
      end
    end

    if cache
      @logger.debug(sprintf('caching [users] at [%s]', Time.now.asctime))
      self.deltas[:users] = res
      self.cache[:users]  = Time.now.to_i
    end

    res
  end
end