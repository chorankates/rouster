require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/tests'
require 'test/unit'

class TestIsInFile < Test::Unit::TestCase

  SHIBBOLETH = 'foobar'

  def setup
    assert_nothing_raised do
      # no reason not to do this as a passthrough once we can
      @app = Rouster.new(:name => 'app', :sudo => false)
      @app.up()
    end

    # create some temporary files
    @dir_tmp = sprintf('/tmp/rouster-%s.%s', $$, Time.now.to_i)
    @app.run(sprintf('mkdir %s', @dir_tmp))

    @file = sprintf('%s/file', @dir_tmp)
    @app.run(sprintf('echo %s >> %s', SHIBBOLETH, @file))
  end

  def teardown; end

  def test_positive

    assert_equal(true, @app.is_in_file?(@file, SHIBBOLETH))

  end

  def test_negative

    assert_equal(false, @app.is_in_file?(@file, 'fizzbuzz'))

  end

end
