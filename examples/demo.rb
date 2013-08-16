require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/tests'

@app = Rouster.new(:name => 'app', :sudo => true, :verbosity => 4)

# get list of packages
before_packages = @app.get_packages()

# install new package
@app.run('yum -y install httpd')

# get list of packages
after_packages = @app.get_packages(false)

# look for files specific to new pacakge
p sprintf('delta of before/after packages: %s', after_packages - before_packages)
p sprintf('/var/www exists: %s', @app.is_dir?('/var/www'))
p sprintf('/etc/httpd/conf/httpd.conf: %s', @app.file('/etc/httpd/conf/httpd.conf'))

# look for port state changes
@app.run('service httpd start')
httpd_on_ports = @app.get_ports()
p sprintf('while httpd is running, port 80 is: %s', @app.is_port_active?(80))

@app.run('service httpd stop')
httpd_off_ports = @app.get_ports()

p sprintf('delta of before/after ports: %s', httpd_off_ports - httpd_on_ports)
p sprintf('when httpd is stopped, port 80 is: %s', @app.is_port_active?(80))

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


# get a conf file, modify it, send it back, restart service
