require_relative '../test_helper'
require 'timeout'

class GuardProcessTest < MiniTest::Unit::TestCase
  def setup
    ENV['GUARD_ENV'] = 'test'
    @command = "ruby #{TEST_ROOT}/run_me.rb"
    @name = "RunMe"
    @options = {:command => @command, :name => @name}
    @guard = Guard::Process.new([], @options)
  end

  def teardown
    @guard.stop if @guard.process_running?
    ENV['GUARD_ENV'] = nil
  end

  def test_run_all_returns_true
    assert @guard.run_all
  end

  def test_run_on_changes_does_a_reload
    @guard.expects(:reload)
    @guard.run_on_changes("")
  end

  def test_start_runs_command_and_stop_stops_it
    Guard::UI.expects(:info).with("Starting process #{@name}")
    Guard::UI.expects(:info).with("Started process #{@name}")
    @guard.start
    assert @guard.process_running?
    Guard::UI.expects(:info).with("Stopping process #{@name}")
    Guard::UI.expects(:info).with("Stopped process #{@name}")
    @guard.stop
    refute @guard.process_running?
  end

  def test_reload_stops_and_starts_command
    @guard.start
    assert @guard.process_running?
    @guard.reload
    assert @guard.process_running?
  end

  def test_start_sets_env_properly
    ENV['VAR1'] = 'VALUE A'
    @options[:env] = {'VAR1' => 'VALUE 1', 'VAR3' => 'VALUE 2'}

    environment_file = "#{TEST_ROOT}/test_environment.txt"
    File.delete(environment_file) if File.exists?(environment_file)

    @guard = Guard::Process.new([], @options)
    @guard.start

    # Check the environment
    assert_equal ENV['VAR1'], 'VALUE A'
    assert_nil ENV['VAR2']
    assert_nil ENV['VAR3']

    # Wait for run_me.rb to write the environment details to file
    Timeout.timeout(30) do
      until File.exist?("#{TEST_ROOT}/test_environment.txt") do
        sleep 0.5
      end
    end

    # Read the written environment and convert it to a Hash, and get rid of the file
    written_env = Hash[File.read("#{TEST_ROOT}/test_environment.txt").split("\n").map {|l| l.split(" = ")}]
    File.delete("#{TEST_ROOT}/test_environment.txt")

    # Verify that the written environment matches what was set in options[:env]
    assert_equal 'VALUE 1', written_env['VAR1']
    assert_equal nil, written_env['VAR2']
    assert_equal 'VALUE 2', written_env['VAR3']
  end

  def test_commands_are_formatted_properly_for_spoon
    @options = {:command => 'echo test test', :name => 'EchoProcess', :env => {"VAR1" => "VALUE 1"}}
    ::Process.stubs(:kill).returns(true)

    Spoon.expects(:spawnp).with("echo", "test", "test").returns(stub_everything)

    @guard = Guard::Process.new([], @options)
    @guard.start and @guard.stop
  end
end
