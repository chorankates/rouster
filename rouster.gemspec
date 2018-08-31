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
  s.license       = 'BSD-3-Clause'

  s.required_rubygems_version = '>= 1.3.6'
  s.rubyforge_project         = 'Rouster'

  s.add_dependency 'json', '~> 2.1'
  s.add_dependency 'log4r', '~> 1.1'
  s.add_dependency 'net-scp', '~> 1.2'
  s.add_dependency 'net-ssh', '~> 2.9'
  s.add_dependency 'rake', '~> 10.4'

  s.add_development_dependency 'test-unit', '~> 2.0'
  s.add_development_dependency 'reek', '~> 5.0'

  s.files = `git ls-files`.split("\n")
end
