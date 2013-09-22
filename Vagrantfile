# stripped down example piab Vagrantfile for rouster

box_url  = 'http://puppet-vagrant-boxes.puppetlabs.com/centos-64-x64-vbox4210.box'
box_name = 'centos6'
boxes    = [:ppm, :app]

Vagrant.configure("1") do |config|
  boxes.each do |box|
    config.vm.define box do |worker|

      worker.vm.box            = box_name
      worker.vm.box_url        = box_url
      worker.vm.host_name      = box.to_s
      worker.vm.network        :hostonly, sprintf('10.0.1.%s', rand(253).to_i + 1)
      worker.ssh.forward_agent = true

    end
  end
end
