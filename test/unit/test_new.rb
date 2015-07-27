require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'test/unit'

# TODO add a bad perms test -- though it should be fixed automagically

class TestNew < Test::Unit::TestCase

  def setup
    @app = nil
    # TODO make this work, don't want to have to instance_variable_get everything..
    #Rouster.send(:public, *Rouster.instance_variables)
  end

  # TODO this is an awful pattern, do better

  def test_1_good_basic_instantiation

    assert_nothing_raised do
      @app = Rouster.new(:name => 'app', :unittest => true)
    end

    assert_equal('app', @app.name)
    assert_equal(false, @app.is_passthrough?())
    assert_equal(true, @app.uses_sudo?())
  end

  def test_2_good_instantiation

    assert_nothing_raised do
      @app = Rouster.new(
        :cache_timeout => 10,
        :name          => 'ppm',
        :retries       => 3,
        :verbosity     => [3,2],
        :unittest      => true,
      )
    end

    assert_equal(10, @app.cache_timeout)
    assert_equal('ppm', @app.name)
    assert_equal(3, @app.retries)

    assert_equal(3, @app.instance_variable_get(:@verbosity_console))
    assert_equal(2, @app.instance_variable_get(:@verbosity_logfile))

  end


  def test_default_overrides_aws_passthrough

    key = sprintf('%s/.ssh/id_rsa', ENV['HOME'])
    omit(sprintf('no suitable private key found at [%s]', key)) unless File.file?(key)

    @app = Rouster.new(
      :name => 'aws',
      :passthrough => {
        :type       => :aws,
        :ami        => 'ami-1234',
        :keypair    => 'you@aws',
        :key        => key,
        :key_id     => 'key',
        :secret_key => 'secret_access_key',

        # aws specific overrides
        :region => 'us-east-2',
        :user   => 'cloud-user',

        # generic passthrough overrides
        :ssh_sleep_ceiling => 1,
        :ssh_sleep_time    => 1,
      },

      :unittest => true,
    )

    passthrough = @app.passthrough

    assert_equal('us-east-2', passthrough[:region])
    assert_equal('cloud-user', passthrough[:user])
    assert_equal(1, passthrough[:ssh_sleep_ceiling])
    assert_equal(1, passthrough[:ssh_sleep_time])

    assert_not_nil(passthrough[:ami])
    assert_not_nil(passthrough[:key_id])
    assert_not_nil(passthrough[:min_count])
    assert_not_nil(passthrough[:max_count])
    assert_not_nil(passthrough[:size])
    assert_not_nil(passthrough[:ssh_port])

  end

  def test_default_overrides_passthrough

    @app = Rouster.new(
      :name => 'local',
      :passthrough => {
        :type              => :local,
        :paranoid          => :secure,
        :ssh_sleep_ceiling => 100,
      },

      :unittest => true,
    )

    passthrough = @app.passthrough

    assert_equal(:secure, passthrough[:paranoid])
    assert_equal(100, passthrough[:ssh_sleep_ceiling])
    assert_not_equal(100, passthrough[:ssh_sleep_time])
  end


  def teardown
    # noop
  end

end
