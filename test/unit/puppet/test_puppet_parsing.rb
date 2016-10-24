require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'test/unit'

# this is a unit test, no need for a real Rouster VM

class TestGetPuppetStar < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app', :unittest => true)
    end

    # expose private methods
    Rouster.send(:public, *Rouster.protected_instance_methods)
  end

  def test_with_successful_exec
    title = 'foo'
    input = File.read(sprintf('%s/../../../test/unit/puppet/resources/puppet_run_with_successful_exec', File.dirname(File.expand_path(__FILE__))))


    assert(@app.did_exec_fire?(title, input))
  end

  def test_with_failed_exec
    title = 'bar'
    input = File.read(sprintf('%s/../../../test/unit/puppet/resources/puppet_run_with_failed_exec', File.dirname(File.expand_path(__FILE__))))

    assert(@app.did_exec_fire?(title, input))
  end

  def test_looking_for_nonexistent_exec
    title = 'fizzbang'
    input = File.read(sprintf('%s/../../../test/unit/puppet/resources/puppet_run_with_successful_exec', File.dirname(File.expand_path(__FILE__))))

    assert_false(@app.did_exec_fire?(title, input))
  end


end

