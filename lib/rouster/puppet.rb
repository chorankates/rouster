require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

class Rouster

    def compile_catalog(hostname)
      # TODO determine what our inputs should be
      # TODO determine what/how to call puppet to do this
      raise NotImplementedError.new()
    end

    def run_puppet
      self.run('/sbin/service puppet once -t')
    end

    def get_puppet_errors(input = nil)
      str = input.nil? ? self.get_output() : input

      raise NotImplementedError.new()
    end

    def get_puppet_notices(input = nil)
      str = input.nil? ? self.get_output() : input

      raise NotImplementedError.new()
    end

end