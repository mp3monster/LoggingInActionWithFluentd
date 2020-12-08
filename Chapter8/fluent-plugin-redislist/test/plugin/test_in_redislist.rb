require "helper"
require "fluent/plugin/in_redislist.rb"

class RedislistInputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  test "failure" do
    flunk
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::RedislistInput).configure(conf)
  end
end
