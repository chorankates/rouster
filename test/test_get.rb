require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rouster'
require 'rouster/tests'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup
    @app = Rouster.new(:name => 'app')

    @app.up()

    @kg_local_location  = sprintf('/tmp/rouster-test_get_local.%s.%s', $$, Time.now.to_i)
    @kg_local_location.freeze
    @kg_remote_location = '/etc/hosts'
    @kb_dne_location    = '/tmp/this-doesnt_exist/and/never/will.txt'

    File.delete(@kg_local_location) if File.file?(@kg_local_location).true?

    assert_equal(@app.is_available_via_ssh?, true, 'app is available via SSH')
    assert_equal(File.file?(@kg_local_location), false, 'test KG file not present')
  end

  def test_happy_path

    assert_nothing_raised do
      @app.get(@kg_remote_location, @kg_local_location)
    end

    assert(File.file?(@kg_local_location))
  end

  def test_local_path_dne

    assert_raise Rouster::FileTransferError do
      @app.get(@kg_remote_location, @kb_dne_location)
    end

    assert_equal(false, File.file?(@kg_local_location), 'known bad local path DNE')
  end

  def test_remote_path_dne

    assert_raise Rouster::FileTransferError do
      @app.get(@kb_dne_location, @kg_local_location)
    end

    assert_equal(false, File.file?(@kg_local_location), 'known bad remote file path DNE')

  end

  def test_with_suspended_machine
    @app.suspend()

    assert_raise Rouster::SSHConnectionError do
      @app.get(@kg_remote_location, @kg_local_location)
    end

    assert_equal(false, File.file?(@kg_local_location), 'when machine is suspended, unable to get from it')
  end

  def teardown
    # TODO we should suspend instead if any test failed for triage
    #@app.destroy()
    #@ppm.destroy()

    File.delete(@kg_local_location) if File.file?(@kg_local_location).true?
  end
end