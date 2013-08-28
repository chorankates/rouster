require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'test/unit'

# this is technically a unit test, no need for a real Rouster VM

class TestGetPuppetStar < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

    # expose private methods
    Rouster.send(:public, *Rouster.protected_instance_methods)
  end

  def test_happy_get_errors

    output = "[1;35merr: Could not retrieve catalog from remote server: Error 400 on SERVER: no result for [api_vip] in Hiera (YAML/CMS)[0m\nfizzybang\n[1;35merr: Could not retrieve catalog from remote server: Error 400 on SERVER: no result for [foobar] in Hiera (YAML/CMS)[0m"
    @app.output.push(output)

    assert_not_nil(@app.get_puppet_errors())
    assert_equal(2, @app.get_puppet_errors().size)

    assert_nil(@app.get_puppet_notices())

  end

  def test_happy_get_notices

    output = "[0;36mnotice: Not using cache on failed catalog[0m\nfizzbang\n[0;36mnotice: Not using cache on failed catalog[0m"
    @app.output.push(output)

    assert_not_nil(@app.get_puppet_notices())
    assert_equal(2, @app.get_puppet_notices().size)

    assert_nil(@app.get_puppet_errors())

  end

  def test_no_errors

    output = 'there are no errors here'
    @app.output.push(output)

    assert_nil(@app.get_puppet_errors())
  end

  def test_no_notices

    output = 'there are no notices here'
    @app.output.push(output)

    assert_nil(@app.get_puppet_notices())

  end

  def teardown
    # noop
  end

end

