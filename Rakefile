require sprintf('%s/%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')
require 'rubygems'
require 'rake/testtask'

desc 'build the gem'
task :buildgem do
  sh 'gem build rouster.gemspec'
end

desc 'cleanup environment'
task :clean do
  sh 'rm /tmp/rouster-*'
end

task :default do
  sh 'ruby test/basic.rb'
end

desc 'run the example demo'
task :demo do
  sh 'ruby examples/demo.rb'
end

desc 'rdoc generation'
task :doc do
  sh 'rdoc --line-numbers lib/*'
end

task :examples do
  Dir['examples/**/*.rb'].each do |example|
	  sh "ruby #{example}"
	end
end

desc 'shortcut to vagrant destroy -f'
task :vdestroy do
  sh 'vagrant destroy -f'
end

desc 'reek validation'
task :reek do
  sh 'reek lib/**/*.rb'
end

namespace :test do
  Rake::TestTask.new(:all => :vdestroy) do |t|
    t.description = 'run all tests'
    t.libs << 'lib'
    t.test_files = FileList['test/**/test_*.rb']
  end

  Rake::TestTask.new do |t|
    t.name = 'unit'
    t.description = 'run unit tests'
    t.libs << 'lib'
    t.test_files = FileList['test/unit/**/test_*.rb']
  end

  Rake::TestTask.new(:functional => :vdestroy) do |t|
    t.description = 'run functional tests'
    t.libs << 'lib'
    t.test_files = FileList['test/functional/**/test_*.rb']
  end

  Rake::TestTask.new(:deltas => :vdestroy) do |t|
    t.description = 'run delta tests'
    t.libs << 'lib'
    t.test_files = FileList['test/functional/deltas/test_*.rb']
  end

  Rake::TestTask.new do |t|
    t.name        = 'puppet'
    t.description = 'run puppet tests'
    t.libs << 'lib'
    t.test_files  = FileList['test/puppet/test*.rb']
    t.verbose = true
  end
end
