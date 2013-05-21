require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup
    @app = nil
  end

  def test_1_good_openssh_tunnel
    @app = Rouster.new(:name => 'app', :sshtunnel => true)

    @app.destroy() if @app.get_status().eql?('running')

    # TODO how do we properly test this? we really need the rspec should_call mechanism...  end
  end

  def teardown
    # noop
  end

end
