# stripped down piab Vagrantfile for rouster

box_url   = "rhel6_u2_v2.box"

boxes = [:ppm, :app]

Vagrant::Config.run do |config|
  boxes.each do |box|
    config.vm.define box do |worker|

      worker.vm.box = 'rhel6_u2_v2'
      worker.vm.box_url = box_url
      worker.vm.host_name = box.to_s
      worker.ssh.forward_agent =  true

      if box.to_s.eql?('ppm')
        worker.vm.share_folder("isd-puppet", "/etc/puppet/", "../sfdc/puppet/")
      end

    end
  end
end
