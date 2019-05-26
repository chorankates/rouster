require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/tests'

@app = Rouster.new(:name => 'app', :sudo => true)
@app.up()

# get list of packages
before_packages = @app.get_packages()

# need this if not on vpn
@app.run('wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm')
@app.run('wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm')
@app.run('rpm -Uvh remi-release-6*.rpm epel-release-6*.rpm', [0,2])
@app.run('yum makecache')

# install new package
@app.run('yum -y install httpd')
print @app.get_output()

# get list of packages
after_packages = @app.get_packages(false)

# look for files specific to new pacakge
p sprintf('delta of before/after packages: %s', after_packages.keys() - before_packages.keys())
p sprintf('/var/www exists: %s', @app.is_dir?('/var/www'))
p sprintf('/etc/httpd/conf/httpd.conf: %s', @app.file('/etc/httpd/conf/httpd.conf'))

# look for port state changes
httpd_off_ports = @app.get_ports()

@app.run('service httpd start')
httpd_on_ports = @app.get_ports()
p sprintf('while httpd is running, is_port_active?(80): %s', @app.is_port_active?(80, 'tcp', true))
p sprintf('delta of before/after ports: %s', httpd_on_ports['tcp'].keys() - httpd_off_ports['tcp'].keys())

# look for groups/users created
p sprintf('apache group created? %s', @app.is_group?('apache'))
p sprintf('apache user created?  %s', @app.is_user?('apache'))

# look at is_process_running / is_service / is_service_running
is_service = @app.is_service?('httpd')
is_service_running = @app.is_service_running?('httpd')
is_process_running = @app.is_process_running?('httpd')
p sprintf('is_service?(httpd) %s', is_service)
p sprintf('is_service_running?(httpd) %s', is_service_running)
p sprintf('is_process_running?(httpd) %s', is_process_running)

@app.run('service httpd stop')
is_service_running = @app.is_service_running?('httpd')
p sprintf('is_service_running?(httpd) %s', is_service_running)
p sprintf('when httpd is stopped, is_port_active(80): %s', @app.is_port_active?(80))

# get a conf file, modify it, send it back, restart service
tmp_filename = sprintf('/tmp/httpd.conf.%s', Time.now.to_i)

@app.get('/etc/httpd/conf/httpd.conf', tmp_filename)

## this should be smoother..
@app._run(sprintf("sed -i 's/Listen 80/Listen 1234/' %s", tmp_filename))
@app.put(tmp_filename)
@app.run("mv #{File.basename(tmp_filename)} /etc/httpd/conf/httpd.conf") # the ssh tunnel runs under the vagrant user

@app.run('service httpd start')
is_service_running = @app.is_service_running?('httpd')
p sprintf('is_service_running?(httpd): %s', is_service_running)
p sprintf('after modification and restart, is_port_active?(1234): %s', @app.is_port_active?(1234))
p sprintf('after modification and restart, is_port_active?(80): %s', @app.is_port_active?(80))

@app._run(sprintf('rm %s', tmp_filename))