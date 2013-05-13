require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

##
# this library is a container for various Vagrant tweaks/extensions

module Vagrant
  module Communication

    class SSH < Base
      # need this to be able to recreate a connection after upping/suspending a box
      def destroy_ssh_connection
        @connection = nil
      end
    end

  end
end
