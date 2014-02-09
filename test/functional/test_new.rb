require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

# TODO rename this to 'test_instantiate' and flesh out tests for all instantiaion options

class TestNew < Test::Unit::TestCase

  def setup
    @app = Rouster.new(:name => 'app', :sshtunnel => false)
    @app.destroy() if @app.status().eql?('running')
    @app = nil
  end

  def test_1_able_to_instantiate

    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

  end

  def test_2_defults

    assert_nothing_raised do
      @app = Rouster.new(:name => 'app')
    end

    assert_equal('app', @app.name)
    assert_equal(false, @app.cache_timeout)
    assert_equal(false, @app.instance_variable_get(:@logfile))
    assert_equal(false, @app.is_passthrough?())
    assert_equal(0, @app.retries)
    assert_equal(true, @app.instance_variable_get(:@sshtunnel))
    assert_equal(false, @app.instance_variable_get(:@unittest))
    assert_equal(false, @app.instance_variable_get(:@vagrant_concurrency))
    assert_equal(3, @app.instance_variable_get(:@verbosity_console))
    assert_equal(2, @app.instance_variable_get(:@verbosity_logfile))

  end

  def test_2_good_openssh_tunnel
    @app = Rouster.new(:name => 'app', :sshtunnel => true)
                                           7
    # TODO how do we properly test this? we really need the rspec should_call mechanism...
    assert_equal(true, @app.is_available_via_ssh?)
  end

  def test_3_good_advanced_instantiation

    assert_nothing_raised do
      @app = Rouster.new(
        :name          => 'app',
        :passthrough   => false,
        :sudo          => false,
        :verbosity     => [4,0],
        #:vagrantfile  => traverse_up(Dir.pwd, 'Vagrantfile'), # this is what happens anyway..
        :sshkey        =>  ENV['VAGRANT_HOME'].nil? ? sprintf('%s/.vagrant.d/insecure_private_key', ENV['HOME']) : sprintf('%s/insecure_private_key', ENV['VAGRANT_HOME']),
        :cache_timeout => 10,
        :logfile       => true,
      )

    end

    assert_equal('app', @app.name)
    assert_equal(false, @app.is_passthrough?())
    assert_equal(false, @app.uses_sudo?())
    assert_equal(4, @app.instance_variable_get(:@verbosity_console))
    assert_equal(0, @app.instance_variable_get(:@verbosity_logfile))
    assert_equal(true, File.file?(@app.vagrantfile))
    assert_equal(true, File.file?(@app.sshkey))
    assert_equal(10, @app.cache_timeout)

    ## logfile validation -- do we need to do more here?
    logfile = @app.instance_variable_get(:@logfile)

    assert_not_equal(true, logfile)
    assert(File.file?(logfile))

    contents = File.read(logfile)
    assert_not_nil(contents)
  end

  def test_4_bad_name_instantiation

    assert_raise Rouster::ArgumentError do
      @app = Rouster.new(:name => 'foo')
    end

    assert_raise Rouster::ArgumentError do
      @app = Rouster.new(:not_a_name => 'test')
    end

  end

  def test_5_bad_vagrantfile_instantiation

    assert_raise Rouster::InternalError do
      @app = Rouster.new(:name => 'FIZZY') # auto find Vagrantfile
    end

    assert_raise Rouster::ArgumentError do
      @app = Rouster.new(:name => 'testing', :vagrantfile => '/this/file/dne')
    end

  end

  def test_6_bad_sshkey_instantiation

    assert_raise Rouster::ArgumentError do
      @app = Rouster.new(:name => 'app', :sshkey => '/this/file/dne')
    end

  end


  def teardown
    # noop
  end

end
