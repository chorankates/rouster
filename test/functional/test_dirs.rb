require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/tests'
require 'test/unit'

class TestDirs < Test::Unit::TestCase

  def setup
    @app = Rouster.new(:name => 'app', :verbose => 1)
    @app.up()

    @dir = sprintf('/tmp/rouster.dirs.%s/', Time.now.to_i)
  end

  def test_happy
    dirs_expected = ['foo', 'bar', 'baz']

    dirs_expected.each do |dir|
      @app.run(sprintf('mkdir -p %s/%s', @dir, dir))
    end

    dirs_actual = @app.dirs(@dir)

    # could totally use an is_deeply here..
    dirs_actual.each do |dir|
      dir = dir.gsub(/#{@dir}/, '') # remove the path prefix
      assert(dirs_expected.member?(dir))
    end

  end

  def test_happy_filter

    dirs_to_create = ['foo', 'bar', 'baz']
    dirs_expected  = ['bar', 'baz']

    dirs_to_create.each do |dir|
      @app.run(sprintf('mkdir -p %s/%s', @dir, dir))
    end

    dirs_actual = @app.dirs(@dir, 'b*')

    # would like to do some negative testing here
    dirs_actual.each do |dir|
      dir = dir.gsub(/#{@dir}/, '') # remove the path prefix
      assert(dirs_expected.member?(dir))
    end


  end

  def no_test_happy_recurse

    raise NotImplementedError.new()

  end

  def teardown
    @app.run(sprintf('rm -rf %s', @dir))
  end

end
