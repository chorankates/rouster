require sprintf('%s/../../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')
require 'net/scp'

# this library is a container for various Vagrant tweaks/extensions


module Vagrant
  module Communication

    class SSH < Base

      def destroy_ssh_connection
        # need this to be able to recreate a connection after upping/suspending a box
        @connection = nil
      end

      def download(from, to)
        # Vagrant::Communication::SSH has upload(), but no corresponding download()
        @logger.debug("Downloading: #{from} to #{to}")

        begin
          connect do |connection|
            scp = Net::SCP.new(connection)
            scp.download!(from, to)
          end
        rescue Net::SCP::Error => e
          raise Errors::SCPUnavailable if e.message =~ /\(127\)/
          raise
        end
      end

    end

  end
end
