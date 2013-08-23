require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/tests'
require 'test/unit'

class TestDirs < Test::Unit::TestCase

  def setup
    @app = Rouster.new(:name => 'app')
    @app.up()

    @dir = sprintf('/tmp/rouster.dirs.%s', Time.now.to_i)
  end

  def test_happy
    dirs_expected = ['foo', 'bar', 'baz']

    dirs_expected.each do |dirs|
      @app.run(sprintf('mkdir -p %s/%s', @dir, dirs))
    end

    dirs_actual = @app.dirs(@dir)

    # could totally use an is_deeply here..
    dirs_actual.each do |dir|
      assert(dirs_expected.member?(dir))
    end

  end

  def teardown
    # noop
  end

end
