require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/puppet'
require 'rouster/testing'
require 'test/unit'

class TestValidateCron < Test::Unit::TestCase

  def setup
    # expose private methods
    Rouster.send(:public, *Rouster.private_instance_methods)
    Rouster.send(:public, *Rouster.protected_instance_methods)

    fake_facts = { 'is_virtual' => 'true', 'timezone' => 'PDT', 'uptime_days' => 42 }

    fake_crons = {
      'root' => {
        'printf > /var/log/apache/error_log' => {
          :minute => 10,
          :hour   => 2,
          :dom    => '*',
          :mon    => '*',
          :dow    => '*'
        }
      },
      'a_user' => {
        '/home/a_user/test.pl' => {
          :minute => '0',
          :hour   => ['0', '6', '12', '18'],
          :dom    => '*',
          :mon    => '*',
          :dow    => '*'
        }
      }, 'cronless_user' => {}
    }

    @app = Rouster.new(:name => 'app', :unittest => true)
    @app.deltas[:crontab] = fake_crons
    @app.facts = fake_facts
  end

  def test_positive_basic

    assert(@app.validate_cron('root', 'printf > /var/log/apache/error_log', { :minute => 10, :hour => 2, :dom => '*', :mon => '*', :dow => '*'}))
    assert(@app.validate_cron('a_user', '/home/a_user/test.pl', { :minute => '0', :hour => ['0', '6', '12', '18'], :dom => '*', :mon => '*', :dow => '*' }))
    assert(@app.validate_cron('root', 'chmod 1777 /tmp', { :ensure => 'absent' }))
    assert(@app.validate_cron('cronless_user', 'rm -f /tmp/foo', { :ensure => 'absent' }))

  end

  def test_positive_constrained

    assert(@app.validate_cron('root', 'printf > /var/log/apache/error_log', { :minute => 10 , :constrain => 'is_virtual true'} ))

  end

  def test_negative_basic

    assert_equal(false, @app.validate_cron('root', 'printf > /var/log/apache/error_log', { :minute => 1 }))
    assert_equal(false, @app.validate_cron('root', 'rm -rf /', { :minute => '*', :hour => '*', :dom => '*', :mon => '*', :dow => '*'}))
    assert_equal(false, @app.validate_cron('a_user', '/home/a_user/test.pl', { :ensure => 'absent' }))
    assert_equal(false, @app.validate_cron('root', '/home/a_user/test.pl', { :minute => '0', :hour => ['0', '6', '12', '18'], :dom => '*', :mon => '*', :dow => '*' }))

  end

  def test_negative_constrained

    assert(@app.validate_cron('root', 'printf > /var/log/apache/error_log', { :minute => 10, :constrain => 'is_virtual false' } ))
    assert(@app.validate_cron('root', 'printf > /var/log/apache/error_log', { :gid => 55, :constrain => 'is_virtual false' } ))

  end

  def teardown
    # noop
  end

end
