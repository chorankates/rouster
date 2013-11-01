require sprintf('%s/../../../path_helper', File.dirname(File.expand_path(__FILE__)))

require 'rouster'
require 'rouster/deltas'
require 'test/unit'

class TestDeltasGetPorts < Test::Unit::TestCase

  def setup
    assert_nothing_raised do
      @app = Rouster.new(:name => 'app', :cache_timeout => 10)
    end

    @app.up()
  end

  def test_happy_path
    res = nil

    assert_nil(@app.deltas[:ports])

    assert_nothing_raised do
      res = @app.get_ports()
    end

    assert_equal(Hash, res.class)

    res.each_key do |proto|
      assert_not_nil(res[proto])

      res[proto].each_key do |port|
        assert_not_nil(res[proto][port])
      end

    end

    assert_nil(@app.deltas[:ports])

  end

  def test_happy_path_caching

    assert_nil(@app.deltas[:ports])

    assert_nothing_raised do
      @app.get_ports(true)
    end

    assert_equal(Hash, @app.deltas[:ports].class)

  end

  # TODO this probably isn't the right placefor this test..
  def test_functional_tests

    # TODO this is still wrong, since the data structure may change further
    stock = {
        "udp"=>
          {"123"=>
            {:address=>
              {"fe80::a00:27ff:fe30:a00b"=>"you_might_not_get_it",
               "::1"=>"you_might_not_get_it",
               "0.0.0.0"=>"you_might_not_get_it",
               "fe80::a00:27ff:fe42:f532"=>"you_might_not_get_it",
               "127.0.0.1"=>"you_might_not_get_it",
               "::"=>"you_might_not_get_it",
               "10.0.2.15"=>"you_might_not_get_it",
               "10.0.1.104"=>"you_might_not_get_it",
               "192.168.1.161"=>"you_might_not_get_it"
              }
            },
             "68"=>
                {:address=>
                  {"0.0.0.0"=>"you_might_not_get_it"}
                },
             "111"=>
               {:address=>
                 {"0.0.0.0"=>"you_might_not_get_it", "::"=>"you_might_not_get_it"}
               },
             "840"=>
               {:address=>
                 {"0.0.0.0"=>"you_might_not_get_it", "::"=>"you_might_not_get_it"}
               },
             "161"=>
               {:address=>
                 {"0.0.0.0"=>"you_might_not_get_it"}
               }
            },
        "tcp"=>
          {"111"=>{:address=>{"0.0.0.0"=>"LISTEN", "::"=>"LISTEN"}},
           "199"=>{:address=>{"127.0.0.1"=>"LISTEN"}},
           "25"=>{:address=>{"127.0.0.1"=>"LISTEN"}},
           "22"=>{:address=>{"0.0.0.0"=>"LISTEN", "::"=>"LISTEN"}}
          }
    }

    @app.deltas[:ports] = stock
    @app.cache[:ports]  = Time.now.to_i # since we're faking the contents, we also need to fake other artifacts that would have been generated

    assert_equal(true, @app.is_port_open?(1234, 'tcp', true))
    assert_equal(true, @app.is_port_active?(22, 'tcp', true))

    assert_equal(true, @app.is_port_open?(303, 'udp', true))
    assert_equal(true, @app.is_port_active?(123, 'udp', true))

    # expected to return false
    assert_equal(false, @app.is_port_open?(22, 'tcp', true))
    assert_equal(false, @app.is_port_active?(1234, 'tcp', true))

    # caching/argument default validation -- can't currently do this, don't know what ports will be open on others systems
    # TODO but can fix this by running some ncatish commands
    #assert_equal(true, @app.is_port_active?(22))
    #assert_equal(true, @app.is_port_open?(1234))

  end

  def test_happy_path_cache_invalidation
    res1, res2 = nil, nil

    assert_nothing_raised do
      res1 = @app.get_ports(true)
    end

    first_cache_time = @app.cache[:ports]

    sleep (@app.cache_timeout + 1)

    assert_nothing_raised do
      res2 = @app.get_ports(true)
    end

    second_cache_time = @app.cache[:ports]

    assert_equal(res1, res2)
    assert_not_equal(first_cache_time, second_cache_time)
    assert(second_cache_time > first_cache_time)

  end

  def teardown
    @app = nil
  end

end
