# stripped down example piab Vagrantfile for rouster

box_name = 'rhel6_u2'
boxes    = [:ppm, :app]

Vagrant::Config.run do |config|
  boxes.each do |box|
    config.vm.define box do |worker|

      worker.vm.box            = box_name
      worker.vm.box_url        = '%s.box' % box_name
      worker.vm.host_name      = box.to_s
      worker.ssh.forward_agent =true

      if box.to_s.eql?('ppm')
        worker.vm.share_folder("isd-puppet", "/etc/puppet/", "../sfdc/puppet/")
      end

    end
  end
end
