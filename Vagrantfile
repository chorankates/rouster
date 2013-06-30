# stripped down example piab Vagrantfile for rouster

box_name = 'rhel6_u2_v2'
boxes    = [:ppm, :app]

Vagrant.configure("1") do |config|
  boxes.each do |box|
    config.vm.define box do |worker|

      worker.vm.box            = box_name
      worker.vm.box_url        = '%s.box' % box_name
      worker.vm.host_name      = box.to_s
      worker.vm.network        :hostonly, sprintf('10.0.0.%s', rand(254))
      worker.ssh.forward_agent = true

    end
  end
end
