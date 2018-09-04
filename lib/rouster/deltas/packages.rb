

class Rouster
  ##
  # get_packages
  #
  # runs an OS appropriate command to gather list of packages, returns hash:
  # {
  #   packageN => {
  #     package => version|? # if 'deep', attempts to parse version numbers
  #   }
  # }
  #
  # parameters
  # * [cache] - boolean controlling whether data retrieved/parsed is cached, defaults to true
  # * [deep] - boolean controlling whether to attempt to parse extended information (see supported OS), defaults to true
  #
  # supported OS
  # * OSX - runs `pkgutil --pkgs` and `pkgutil --pkg-info=<package>` (if deep)
  # * RedHat - runs `rpm -qa --qf "%{n}@%{v}@%{arch}\n"` (does not support deep)
  # * Solaris - runs `pkginfo` and `pkginfo -l <package>` (if deep)
  # * Ubuntu - runs `dpkg-query -W -f='${Package}\@${Version}\@${Architecture}\n'` (does not support deep)
  #
  # raises InternalError if unsupported operating system
  def get_packages(cache=true, deep=true)
    if cache and ! self.deltas[:packages].nil?

      if self.cache_timeout and self.cache_timeout.is_a?(Integer) and (Time.now.to_i - self.cache[:packages]) > self.cache_timeout
        @logger.debug(sprintf('invalidating [packages] cache, was [%s] old, allowed [%s]', (Time.now.to_i - self.cache[:packages]), self.cache_timeout))
        self.deltas.delete(:packages)
      else
        @logger.debug(sprintf('using cached [packages] from [%s]', self.cache[:packages]))
        return self.deltas[:packages]
      end

    end

    res = Hash.new()

    os = self.os_type

    if os.eql?(:osx)

      raw = self.run('pkgutil --pkgs')
      raw.split("\n").each do |line|
        name    = line
        arch    = '?'
        version = '?'

        if deep
          # can get install time, volume and location as well
          local_res = self.run(sprintf('pkgutil --pkg-info=%s', name))
          version   = $1 if local_res.match(/version\:\s+(.*?)$/)
        end

        if res.has_key?(name)
          # different architecture of an already known package
          @logger.debug(sprintf('found package with already known name[%s], value[%s], new line[%s], turning into array', name, res[name], line))
          new_element = { :version => version, :arch => arch }
          res[name]   = [ res[name], new_element ]
        else
          res[name] = { :version => version, :arch => arch }
        end

      end

    elsif os.eql?(:solaris)
      raw = self.run('pkginfo')
      raw.split("\n").each do |line|
        next if line.match(/(.*?)\s+(.*?)\s(.*)$/).nil?
        name    = $2
        arch    = '?'
        version = '?'

        if deep
          begin
            # who throws non-0 exit codes when querying for legit package information? solaris does.
            local_res = self.run(sprintf('pkginfo -l %s', name))
            arch      = $1 if local_res.match(/ARCH\:\s+(.*?)$/)
            version   = $1 if local_res.match(/VERSION\:\s+(.*?)$/)
          rescue
            arch    = '?' if arch.nil?
            version = '?' if arch.nil?
          end
        end

        if res.has_key?(name)
          # different architecture of an already known package
          @logger.debug(sprintf('found package with already known name[%s], value[%s], new line[%s], turning into array', name, res[name], line))
          new_element = { :version => version, :arch => arch }
          res[name]   = [ res[name], new_element ]
        else
          res[name] = { :version => version, :arch => arch }
        end
      end

    elsif os.eql?(:ubuntu) or os.eql?(:debian)
      raw = self.run("dpkg-query -W -f='${Package}@${Version}@${Architecture}\n'")
      raw.split("\n").each do |line|
        next if line.match(/(.*?)\@(.*?)\@(.*)/).nil?
        name    = $1
        version = $2
        arch    = $3

        if res.has_key?(name)
          # different architecture of an already known package
          @logger.debug(sprintf('found package with already known name[%s], value[%s], new line[%s], turning into array', name, res[name], line))
          new_element = { :version => version, :arch => arch }
          res[name]   = [ res[name], new_element ]
        else
          res[name] = { :version => version, :arch => arch }
        end

      end

    elsif os.eql?(:rhel)
      raw = self.run('rpm -qa --qf "%{n}@%{v}@%{arch}\n"')
      raw.split("\n").each do |line|
        next if line.match(/(.*?)\@(.*?)\@(.*)/).nil?
        name    = $1
        version = $2
        arch    = $3

        if res.has_key?(name)
          # different architecture of an already known package
          @logger.debug(sprintf('found package with already known name[%s], value[%s], new line[%s], turning into array', name, res[name], line))
          new_element = { :version => version, :arch => arch }
          res[name]   = [ res[name], new_element ]
        else
          res[name] = { :version => version, :arch => arch }
        end

      end

    else
      raise InternalError.new(sprintf('VM operating system[%s] not currently supported', os))
    end

    if cache
      @logger.debug(sprintf('caching [packages] at [%s]', Time.now.asctime))
      self.deltas[:packages] = res
      self.cache[:packages]  = Time.now.to_i
    end

    res
  end
end