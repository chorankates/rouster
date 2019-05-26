require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestInspect < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end
  end

  def test_happy_path
    # want to do this with 'assert_method_called' or something similar -- but for now..

    res = @app.inspect()

    assert_match(/passthrough\[false\]/, res)
    assert_match(/sshkey/, res)
    assert_match(/status/, res)
    assert_match(/sudo\[true\]/, res)
    assert_match(/vagrantfile/, res)
  end

  def teardown
    # noop
  end

end