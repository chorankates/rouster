# stripped down example piab Vagrantfile for rouster

boxes = {
  :ppm   => {
    :box_name => 'centos6',
    :box_url  => 'http://puppet-vagrant-boxes.puppetlabs.com/centos-64-x64-vbox4210.box',
  },
  :app   => {
    :box_name => 'centos6',
    :box_url  => 'http://puppet-vagrant-boxes.puppetlabs.com/centos-64-x64-vbox4210.box',
  },

  :centos7    => {
    :box_name => 'centos7',
    :box_url  => 'https://vagrantcloud.com/puppetlabs/boxes/centos-7.2-64-puppet/versions/1.0.1/providers/virtualbox.box',
  },

  :ubuntu12  => {
      :box_name => 'ubuntu12',
      :box_url => 'http://puppet-vagrant-boxes.puppetlabs.com/ubuntu-server-12042-x64-vbox4210.box',
  },

  :ubuntu13     => {
    :box_name => 'ubuntu13',
    :box_url  => 'http://puppet-vagrant-boxes.puppetlabs.com/ubuntu-1310-x64-virtualbox-puppet.box',
  },

}

Vagrant::Config.run do |config|
  boxes.each_pair do |box,hash|
    config.vm.define box do |worker|

      worker.vm.box            = hash[:box_name]
      worker.vm.box_url        = hash[:box_url]
      worker.vm.host_name      = hash[:box_name]
      worker.vm.network        :hostonly, sprintf('10.0.1.%s', rand(253).to_i + 2)
      worker.ssh.forward_agent = true

      if box.to_s.eql?('ppm') and File.directory?('../puppet')
        worker.vm.share_folder('puppet', '/etc/puppet/', '../puppet/')
      end

    end
  end
end
