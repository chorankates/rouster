require '../path_helper'

require 'rouster'
require 'test/unit'

class TestRun < Test::Unit::TestCase

  def setup
    @app = Rouster.new({:name => 'app'})
  end

  def test_it

    workers = [@app]

    workers.each do |w|
      # tear them down and build back up for clean run
      w.destroy()
      w.up()

      res = w.run('puppet agent -t --environment development')
      assert_equal(w.exitcode.eql?(0) or w.exitcode.eql?(2), w.exitcode, "exit code [#{w.exitcode}] considered success")
      assert_match(/Finished catalog/, res, "output contains 'Finished catalog'")

    end
  end

  def teardown
    @ppm.destroy()
  end

end