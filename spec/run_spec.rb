require sprintf('%s/../%s', File.dirname(File.expand_path(__FILE__)), 'path_helper')

require 'rspec'
require 'rouster'

describe Rouster do
  before(:all) do
    @app = Rouster.new({:name => 'app', :verbose => 1})
    @ppm = Rouster.new({:name => 'ppm', :verbose => 1, :sudo => false})

    @app.up()
    #@ppm.up()
  end

  it 'can run a known good command' do
    res = @app.run('ls -l')

    @app.exitcode.should eq(0)
    @app.get_output().should eq(res)
    @app.get_output().should_not eq(nil)
    @app.get_output().should match(/^total\s\d/)

  end

  after(:all) do
    # TODO we should suspend instead if any test failed for triage

    @app.destroy()
    @ppm.destroy()
  end

end