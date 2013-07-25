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

    assert_not_nil(res.match(/passthrough\[false\]/))
    assert_not_nil(res.match(/sshkey/))
    assert_not_nil(res.match(/status/))
    assert_not_nil(res.match(/sudo\[true\]/))
    assert_not_nil(res.match(/vagrantfile/))
    assert_not_nil(res.match(/verbosity\[5\]/))
  end

  def teardown
    # noop
  end

end