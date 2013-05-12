require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

# TODO need to decide if we want to "require 'puppet'" or shell out.. MVP is shell out

class Rouster

  # TODO we should be able to run this without upping the box in question
  def get_catalog(hostname)
    raise NotImplementedError.new()

    res = self.run('puppet catalog download') # downloads to yaml, but where? and with what name?

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