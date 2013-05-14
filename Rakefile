require sprintf('%s/%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')
require 'rubygems'

task :default do
  sh 'ruby test/basic.rb'
end

task :test do
  Dir['test/**/test_*.rb'].each do |test|
    sh "ruby #{test}"
  end
end

task :unittest do
  Dir['test/unit/**/test_*.rb'].each do |test|
    sh "ruby #{test}"
  end
end

task :functionaltest do
  Dir['test/functional/**/test_*.rb'].each do |test|
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

