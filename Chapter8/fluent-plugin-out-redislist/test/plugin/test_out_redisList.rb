require "helper"
require "fluent/plugin/out_redislist.rb"

class RedislistOutputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  test "failure" do
    flunk
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::RedislistOutput).configure(conf)
  end
end
