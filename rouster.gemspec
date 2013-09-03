## heavily modified/copy-paste-replaced from vagrant.gemspec

require './path_helper'
require 'rouster'

Gem::Specification.new do |s|
  s.name          = 'rouster'
  s.version       = Rouster::VERSION
  s.platform      = Gem::Platform::RUBY
  s.author        = 'Conor Horan-Kates'
  s.email         = 'conor.code@gmail.com'
  s.homepage      = 'http://github.com/chorankates/rouster'
  s.summary       = 'Rouster is an abstraction layer for Vagrant'
  s.description   = 'Rouster allows you to programmatically control and interact with your existing Vagrant virtual machines'

  s.required_rubygems_version = '>= 1.3.6'
  s.rubyforge_project         = 'Rouster'

  s.add_dependency 'json'
  s.add_dependency 'log4r',   '~> 1.1.9'
  s.add_dependency 'net-scp'
  s.add_dependency 'net-ssh'
  s.add_dependency 'rake'

  s.add_development_dependency 'test-unit'

  s.files = `git ls-files`.split("\n")
end
