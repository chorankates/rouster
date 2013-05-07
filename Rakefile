require 'rubygems'

# TODO better
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
