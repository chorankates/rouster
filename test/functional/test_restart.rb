  require sprintf('%s/../../path_helper', File.dirname(File.expand_path(__FILE__)))

  require 'rouster'
  require 'test/unit'

  class TestRestart < Test::Unit::TestCase

    def setup
      assert_nothing_raised do
        @app = Rouster.new(:name => 'app', :verbosity => 1)
      end

    end

    def test_happy_path
      @app.up()

      assert_equal(true, @app.is_available_via_ssh?)
      sleep 10
      original_uptime = @app.run('uptime')

      assert_nothing_raised do
        @app.restart()
      end

      count = 0
      until @app.is_available_via_ssh?()
        count += 1
        break if count > 12 # wait up to 2 minutes
        sleep 10
      end

      new_uptime = @app.run('uptime')

      assert_not_equal(original_uptime, new_uptime)

      os = @app.os_type

      if os.eql?(:redhat)

        original_minutes_seconds = $1 if original_uptime.match(/\d+:.*up.*(\d+:\d+)/)
        original_seconds =
            original_minutes_seconds.split(':').at(-3) * 3600 +
            original_minutes_seconds.split(':').at(-2) * 60 +
            original_minutes_seconds.split(':').at(-1)

        new_minutes_seconds = $1 if new_uptime.match(/\d+:.*up.*(\d+:\d+)/)
        new_seconds =
            new_minutes_seconds.split(':').at(-3) * 3600 +
            new_minutes_seconds.split(':').at(-2) * 60 +
            new_minutes_seconds.split(':').at(-1)

        assert_equal(true, original_seconds > new_seconds)
      else
        # noop
        #raise NotImplementedError.new()
      end

    end


    def teardown
      # noop
    end

  end
