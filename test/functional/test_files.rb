require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/tests'
require 'test/unit'

class TestFiles < Test::Unit::TestCase

  def setup
    @app = Rouster.new(:name => 'app')
    @app.up()

    @dir = sprintf('/tmp/rouster.files.%s', Time.now.to_i)
    @app.run(sprintf('mkdir %s', @dir))
  end

  def test_happy
    files_expected = ['foo', 'bar', 'baz']

    files_expected.each do |files|
      @app.run(sprintf('touch %s/%s', @dir, files))
    end

    files_actual = @app.files(@dir)

    # could totally use an is_deeply here..
    files_actual.each do |file|
      assert(files_expected.member?(file))
    end

  end

  def teardown
    # noop
    @app.run(sprintf('rm -r %s', @dir))
  end

end
