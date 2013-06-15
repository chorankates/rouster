require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestRebuild < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

  end

  def test_happy_path
    @app.up()

    assert_equal(true, @app.is_available_via_ssh?)

    uploaded_to = sprintf('/tmp/rouster-test_rebuild.%s.%s', $$, Time.now.to_i)
    @app.put(__FILE__, uploaded_to)

    assert_not_nil(@app.is_file?(uploaded_to))

    assert_nothing_raised do
      @app.rebuild()
    end

    count = 0
    until @app.is_available_via_ssh?()
      count += 1
      break if count > 60 # wait up to 5 minutes
      sleep 10
    end

    assert_equal(false, @app.is_file?(uploaded_to))
  end


  def teardown
    # noop
  end

end
