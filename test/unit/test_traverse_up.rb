require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestTraverseUp < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'default', :unittest => true)
    end

    def @app.exposed_traverse_up(*args)
      traverse_up(*args)
    end

  end

  def test_happy_path
    res = @app.exposed_traverse_up(Dir.pwd, 'Vagrantfile')

    assert_equal(true, File.file?(res))

  end

  def test_file_not_specified
    assert_raises Rouster::InternalError do
      @app.exposed_traverse_up(Dir.pwd)
    end

  end

  def test_failed_to_find
    res = @app.exposed_traverse_up('/tmp', 'this-file-dne')

    assert_nil(res)
  end

  def teardown
    # noop
  end

end