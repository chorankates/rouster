require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

class Rouster

    def compile_catalog(hostname)
      # TODO determine what/how to call puppet to do this
      raise NotImplementedError.new()
    end

    def run_puppet
      # TODO how can we make this more flexible?
      self.run('/sbin/service puppet once -t')
    end

    def get_puppet_errors(input = nil)
      str    = input.nil? ? self.get_output() : input
      errors = str.scan(/35merr:.*/)

      errors.empty? ? nil : errors
    end

    def get_puppet_notices(input = nil)
      str     = input.nil? ? self.get_output() : input
      notices = str.scan(/36mnotice:.*/)

      notices.empty? ? nil : notices
    end

end