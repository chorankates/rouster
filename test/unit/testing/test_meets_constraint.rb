require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'
require 'test/unit'

class TestMeetsConstraint < Test::Unit::TestCase

  def setup
    # expose private methods
    Rouster.send(:public, *Rouster.private_instance_methods)
    Rouster.send(:public, *Rouster.protected_instance_methods)

    fake_facts = { 'is_virtual' => 'true', 'timezone' => 'PDT', 'uptime_days' => 42 }

    @app = Rouster.new(:name => 'app', :unittest => true)
    @app.facts = fake_facts
  end

  def test_positive

    assert(@app.meets_constraint?('is_virtual', 'true'))
    assert(@app.meets_constraint?('timezone', 'PDT'))
    assert(@app.meets_constraint?('uptime_days', 42))
    assert(@app.meets_constraint?('uptime_days', '42'))

  end

  def test_negative

    assert_equal(false, @app.meets_constraint?('is_virtual', false))
    assert_equal(false, @app.meets_constraint?('timezone', 'MST'))
    assert_equal(false, @app.meets_constraint?('uptime_days', 27))
    assert_equal(false, @app.meets_constraint?('uptime_days', '27'))

  end

  def teardown
    # noop
  end

end