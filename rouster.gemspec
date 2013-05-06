## heavily modified/copy-paste-replaced from vagrant.gemspec

$:.unshift File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name          = "Rouster"
  s.version       = Vagrant::VERSION
  s.platform      = Gem::Platform::RUBY
  #s.author        = ['Conor Horan-Kates']
  s.email         = %w[conor.code@gmail.com]
  s.homepage      = 'http://github.com/chorankates/rouster'
  s.summary       = 'Rouster is an abstraction layer for Vagrant'
  s.description   = 'Rouster allows you to programmatically control and interact with your existing Vagrant virtual machines'

  s.required_rubygems_version = '>= 1.3.6'
  s.rubyforge_project         = 'Rouster' # need to create this
 
  s.add_dependency 'vagrant', '~> 1.0.5'
  s.add_dependency 'log4r',   '~> 1.1.9'
  s.add_dependency 'net-ssh', '~> 2.2.2'
  s.add_dependency 'net-scp', '~> 1.0.4'
  
  s.add_development_dependency 'rake'
  s.add_development_dependency 'test/unit'

  #s.files         = `git ls-files`.split("\n")
  #s.executables   = nil
  #s.require_path  = 'lib'
end

