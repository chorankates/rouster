require sprintf('%s/%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')
require 'rubygems'

task :default do
  # TODO implement this, should just be basic object instantiation (?)
  sh 'ruby test/basic.rb'
end

task :test do
  Dir['test/**/*.rb'].each do |test|
    sh "ruby #{test}"
  end
end

task :examples do
  Dir['examples/**/*.rb'].each do |example|
	  sh "ruby #{example}"
	end
end

task :buildgem do
  sh 'gem build rouster.gemspec'
end

