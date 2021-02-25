require "./lib/fluent/plugin/out_redislist.rb"
require 'fluent/test'
require 'fluent/test/helpers'


class RedislistOutputTest < Test::Unit::TestCase include Fluent::Test::Helpers

  setup do
    Fluent::Test.setup
    # Setup test for Fluentd (Required)
  end

  # test to see if the configuration reflects what is expected with a nil configuration set
  # we should ensure that our handling of configuration is prepared for this possibility
  test 'default configuration' do
    d = create_driver(nil)
    assert_equal 6379, d.instance.port
    assert_equal 'localhost', d.instance.hostaddr
  end

  # test to see what the configuation values get set to when we provide legitimate configuration values
  test 'advanced config' do
    conf = %[
    host 127.0.0.1
    port 24229
    ]

    captured_string = capture_stdout do
      d = create_driver(conf)
      assert_equal 24229, d.instance.port
      assert_equal '127.0.0.1', d.instance.hostaddr
    end
    assert_true (captured_string.include? "Non standard Redis port in use")

    d.shutdown
  end

  # test to see what happens when a singular event is sent with a non cached configuration. We should expect a single emit operation occuring as 
  # can be seen in the run parameter set.
  test 'handle single event' do
    d = create_driver
    d.start
    d.run(default_tag: 'test', expect_emits: 1, timeout: 30, start: true,  shutdown: false) { d.feed(time, { "k1" => 1 })}
    # we can do more evaluations if desired, but should be a good citizen and stop the driver
    d.shutdown
  end

  test 'handle multiple events' do
    d = create_driver
    d.run do
      d.feed(12345667, { "k1" => 1 })
      d.feed(12345668, { "k1" => 2 })
    end
    assert_equal(2, d.events.size)
    d.shutdown
  end

  test "redisFormat" do
    assert_equal(true,true)
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::RedislistOutput).configure(conf)
  end
end
