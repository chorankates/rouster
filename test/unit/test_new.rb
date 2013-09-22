require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

# TODO add a bad perms test -- though it should be fixed automagically

class TestNew < Test::Unit::TestCase

  def setup
    @app = nil
  end

  # TODO this is an awful pattern, do better

  def test_1_good_basic_instantiation

    assert_nothing_raised do
      @app = Rouster.new(:name => 'app', :unittest => true)
    end

    assert_equal('app', @app.name)
    assert_equal(false, @app.is_passthrough?())
    assert_equal(true, @app.uses_sudo?())
  end

  def teardown
    # noop
  end

end
