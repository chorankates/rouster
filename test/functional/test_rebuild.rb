require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/tests'
require 'test/unit'

class TestRebuild < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'default')
    end

    @uploaded_to = sprintf('/tmp/rouster-test_rebuild.%s.%s', $$, Time.now.to_i)
  end

  def test_1_happy_path
    @app.up()

    assert_equal(true, @app.is_available_via_ssh?)

    @app.put(__FILE__, @uploaded_to)

    assert_not_nil(@app.is_file?(@uploaded_to))

    assert_nothing_raised do
      @app.rebuild()
    end

    assert_equal(false, @app.is_file?(@uploaded_to))
  end

  def test_2_machine_already_destroyed
    @app.destroy() if @app.status.eql?('running')

    assert_equal(false, @app.is_available_via_ssh?)

    assert_nothing_raised do
      @app.rebuild()
    end

    assert_equal(false, @app.is_file?(@uploaded_to))
  end

  def teardown
    # noop
  end

end
