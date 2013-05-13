require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

##
# this library is a container for various Vagrant tweaks/extensions

module Vagrant
  module Communication

    class SSH < Base

      def destroy_ssh_connection
        # need this to be able to recreate a connection after upping/suspending a box
        @connection = nil
      end
    end

    def download(from, to)
      # Vagrant::Communication::SSH has upload(), but no corresponding download()
      raise NotImplementedError.new()
    end

  end
end
