require 'rubygems'
require 'json'

json = '{"data":{"edges":[{"target":"Class[P4users]","source":"Stage[main]"},{"target":"File[/usr/local/bin/p4]","source":"Class[P4users]"},{"target":"Node[default]","source":"Class[main]"},{"target":"Class[Custom]","source":"Stage[main]"},{"target":"Class[main]","source":"Stage[main]"},{"target":"Class[Settings]","source":"Stage[main]"},{"target":"Class[Baseclass]","source":"Stage[main]"}],"name":"ppm","resources":[{"exported":false,"title":"P4users","tags":["class","p4users","baseclass","node","default"],"type":"Class"},{"exported":false,"line":34,"title":"/usr/local/bin/p4","parameters":{"source":"puppet:///modules/p4users/p4","group":"root","ensure":"present","owner":"root"},"tags":["file","class","p4users","baseclass","node","default"],"type":"File","file":"/etc/puppet/modules/p4users/manifests/init.pp"},{"exported":false,"title":"main","parameters":{"name":"main"},"tags":["stage"],"type":"Stage"},{"exported":false,"title":"default","tags":["node","default","class"],"type":"Node"},{"exported":false,"title":"Custom","tags":["class","custom","baseclass","node","default"],"type":"Class"},{"exported":false,"line":18,"title":"first","parameters":{"before":"Stage[main]"},"tags":["stage","first","class"],"type":"Stage","file":"/etc/puppet/manifests/templates.pp"},{"exported":false,"title":"main","parameters":{"name":"main"},"tags":["class"],"type":"Class"},{"exported":false,"title":"Settings","tags":["class","settings"],"type":"Class"},{"exported":false,"title":"Baseclass","tags":["class","baseclass","node","default"],"type":"Class"}],"tags":["settings","default","baseclass","p4users","custom","node","class"],"classes":["settings","default","baseclass","p4users","custom"],"version":1368977684},"metadata":{"api_version":1},"document_type":"Catalog"}'

hash = JSON.parse(json)

resources = hash['data']['resources']

resources.each do |e|
	print sprintf('%s%s', e, "\n")
end


exit!
