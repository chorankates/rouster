require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

class TestPut < Test::Unit::TestCase

  def setup
    @app = nil
  end

  # TODO this is an awful pattern, do better

  def test_1_good_basic_instantiation

    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

    assert_equal('app', @app.name)
    assert_equal(false, @app.is_passthrough?())
    assert_equal(true, @app.uses_sudo?())
  end

  def test_2_good_advanced_instantiation

    assert_nothing_raised do
      @app = Rouster.new(
              :name        => 'app',
              :passthrough => true,
              :sudo        => false,
              :verbose     => 2,
              :vagrantfile => traverse_up(Dir.pwd, 'Vagrantfile'),
              :sshkey      => sprintf('%s/.vagrant.d/insecure_private_key', ENV['HOME'])
      )
    end

    assert_equal('app', @app.name)
    assert_equal(true, @app.is_passthrough?())
    assert_equal(false, @app.uses_sudo?())
    assert_equal(2, @app.verbosity) # is this going to be strinigified?
    asset_equal(true, File.is_file?(@app.vagrantfile))
    assert_equal(true, File.is_file?(@app.sshkey))
  end

  def test_3_bad_name_instantiation

    assert_raise Rouster::InternalError do
      @app = Rouster.new(:name => 'foo')
    end

    assert_raise Rouster::InternalError do
      @app = Rouster.new(:not_a_name => 'test')
    end

  end

  def test_4_bad_vagrantfile_instantiation

    assert_raise Rouster::InternalError do
      @app = Rouster.new(:name => 'FIZZY') # auto find Vagrantfile
    end

    assert_raise Rouster::InternalError do
      @app = Rouster.new(:name => 'testing', :vagrantfile => '/this/file/dne')
    end

  end

  def test_5_bad_sshkey_instantiation

    assert_raise Rouster::InternalError do
      @app = Rouster.new(:name => 'app', :sshkey => '/this/file/dne')
    end

    # TODO add a bad perms test -- though it should be fixed automagically

  end


  def teardown
    # noop
  end

end
