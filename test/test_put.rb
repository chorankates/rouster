require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/tests'
require 'test/unit'

@app = Rouster.new(:name => 'app')
@ppm = Rouster.new(:name => 'ppm', :sudo => false)

@app.up()

class TestPut < Test::Unit::TestCase

  def setup
  #  @app = Rouster.new({:name => 'app'})
  #  @ppm = Rouster.new({:name => 'ppm', :sudo => false})
  #
  #  @app.up()
  #  @ppm.up()
    @kg_location     = sprintf('/tmp/rouster-test_put.%s.%s', $$, Time.now.to_i)
    @kb_dne_location = '/tmp/this-doesnt_exist/and/never/will.txt'
  end

  def test_happy_path

    assert_nothing_raised do
      @app.put(__FILE__, @kg_location)
    end

    assert(@app.is_file?(@kg_location))
  end

  def test_local_file_dne

    assert_raise FileTransferError do
      @app.put('this_file_dne', @kg_location)
    end

    assert_equal(false, @app.is_file?(@kg_location), 'known bad local file DNE')
  end

  def test_remote_path_dne

    assert_raise SSHConnectionError do
      @app.put(__FILE__, @kb_dne_location)
    end

    assert_equal(false, @app.is_file?(@kb_dne_location), 'known bad remote file path DNE')

  end

  #def teardown
  #  # TODO we should suspend instead if any test failed for triage
  #  @app.destroy()
  #  @ppm.destroy()
  #end
end