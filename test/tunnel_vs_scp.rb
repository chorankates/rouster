require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')
require 'rouster'
require 'rouster/tests'

# 'performance' test to determine if we should implement the scp option
# in is_in_file()? -- first run says yes, probably make it off by default

w = Rouster.new(:name => 'default', :verbose => 3)
w.up()

file     = '/etc/hosts'
look_for = [ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j']

print w.is_available_via_ssh?

## through the scp tunnel
start = Time.now
look_for.each do |element|
  print w.is_in_file?(file, element)
end

finish = Time.now

print "\nscp tunnel took #{finish - start}\n"
local = '/tmp/test-ing'

## get the file, then _run against it

w.get(file, local)

start = Time.now
look_for.each do |element|
  begin
    print w._run(sprintf("grep -c '%s' %s", element, local))
  rescue
  end

end
finish = Time.now

print "\nwith a get, took #{finish - start}\n"
