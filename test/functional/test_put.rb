require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/tests'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup
    @app = Rouster.new(:name => 'app')

    @app.up()

    @kg_location     = sprintf('/tmp/rouster-test_put.%s.%s', $$, Time.now.to_i)
    @kb_dne_location = '/tmp/this-doesnt_exist/and/never/will.txt'

    File.delete(@kg_location) if File.file?(@kg_location).true?

    assert_equal(@app.is_available_via_ssh?, true, 'app is available via SSH')
    assert_equal(File.file?(@kg_location), false, 'test KG file not present')

  end

  def test_happy_path

    assert_nothing_raised do
      @app.put(__FILE__, @kg_location)
    end

    assert(@app.is_file?(@kg_location))
  end

  def test_local_file_dne

    assert_raise Rouster::FileTransferError do
      @app.put('this_file_dne', @kg_location)
    end

    assert_equal(false, @app.is_file?(@kg_location), 'known bad local file DNE')
  end

  def test_remote_path_dne

    assert_raise Rouster::FileTransferError do
      @app.put(__FILE__, @kb_dne_location)
    end

    assert_equal(false, @app.is_file?(@kb_dne_location), 'known bad remote file path DNE')

  end

  def test_with_suspended_machine
    @app.is_available_via_ssh?() # make sure we have a tunnel
    @app.suspend()

    #assert_raise Rouster::SSHConnectionError
    assert_raise Rouster::FileTransferError do
      @app.put(__FILE__, @kg_local_location)
    end

    #assert_equal(false, @app.is_file?(@kg_local_location), 'when machine is suspended, unable to get from it')
  end

  def test_with_suspended_machine_after_destroying_ssh_tunnel
    @app.disconnect_ssh_tunnel()
    @app.suspend()

    #assert_raise Rouster::SSHConnectionError do
    assert_raise Rouster::FileTransferError do
      @app.put(__FILE__, @kg_local_location)
    end

    #assert_equal(false, @app.is_file?(@kg_local_location), 'when machine is suspended, and connection is manually destroyed, unable to get from it')
  end

  def teardown
    #@app.destroy()
    #@app.suspend()
    File.delete(@kg_location) if File.file?(@kg_location).true?
  end
end
