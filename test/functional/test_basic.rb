require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup
    @app = Rouster.new(:name => 'app')
    @app.destroy() if @app.status().eql?('running')
  end

  def test_1_able_to_instantiate

    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

  end

  def test_2_good_openssh_tunnel
    @app = Rouster.new(:name => 'app', :sshtunnel => true)

    # TODO how do we properly test this? we really need the rspec should_call mechanism...

    assert_equal(true, @app.is_available_via_ssh?)
  end

  def teardown
    # noop
  end

end
