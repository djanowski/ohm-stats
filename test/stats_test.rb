require "contest"

require "ohm"

begin
  require "ruby-debug"
rescue LoadError
end

$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), "..", "lib")))

require "ohm/stats"
require "models"

class StatsTest < Test::Unit::TestCase

  setup do
    Ohm.redis.flushall

    1.upto 10 do |i|
      post = Post.create(:title => "Redis Meetup #{i}", :body => "Lorem ipsum dolor sit amet.")

      Comment.create(:text => "I liked your post about Redis Meetup #{i}", :post_id => post.id)
      Comment.create(:text => "I too liked your post about Redis Meetup #{i}", :post_id => post.id)
    end
  end

  test "report counts by model" do
    report = Ohm::Stats.new.to_s

    assert report[%r{         Count  Keys  Keys \(%\)  Keys/instance}]
    assert report[%r{Post +10 +42 +36.84% +4.20}]
    assert report[%r{Comment +20 +72 +63.16% +3.60}]
  end

  test "report memory and key size" do
    report = Ohm::Stats.new.to_s

    assert report[%r{Available memory +\d+}]
    assert report[%r{Average key size +\d+}]
    assert report[%r{Maximum amount of keys +\d+}]
  end

  test "binary" do
    report = %x{ruby -Ilib bin/ohm-stats -r test/models.rb}

    puts report
    assert report[/Post/]
  end

end
