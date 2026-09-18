# frozen_string_literal: true

require "test_helper"

class ReplyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  attr_accessor :user

  setup do
    @user = create(:user)
  end

  test "should not valid when Topic was closed" do
    t = create :topic, closed_at: Time.now
    r = build(:reply)
    assert_equal true, r.valid?
    r.topic_id = t.id
    refute_equal true, r.valid?
  end

  test "should not allowed update replies when Topic was closed" do
    t = create :topic
    r = create(:reply, topic: t)
    assert_equal true, r.valid?
    t.close!
    r.body = "new body"
    refute_equal true, r.valid?
    assert_equal false, r.save
    assert_includes r.errors.full_messages.join(""), "Topic has been closed, no longer accepting create or update replies."
  end

  test "should remove bas reply_to_id" do
    t = create(:topic)
    r1 = create(:reply, topic: t)
    r2 = create(:reply)
    r = create(:reply, topic: t, reply_to: r2)
    assert_nil r.reply_to_id
    r = create(:reply, topic: t, reply_to: r1)
    assert_equal r1.id, r.reply_to_id
  end

  test "should delete mention notification after destroy" do
    assert_no_changes -> { user.notifications.unread.count } do
      create(:reply, body: "@#{user.login}").destroy
    end
  end

  test "should send topic reply notification to topic author" do
    perform_enqueued_jobs do
      topic = create :topic, user: user

      assert_changes -> { Notification.count }, 1 do
        create :reply, topic: topic
      end

      assert_no_changes -> { user.notifications.unread.count } do
        create(:reply, topic: topic).destroy
      end

      assert_no_changes -> { user.notifications.unread.count } do
        create :reply, topic: topic, user: user
      end

      # Don't duplicate notifiation with mention
      assert_no_changes -> { user.notifications.unread.where(notify_type: "topic_reply").count } do
        create :reply, topic: topic, mentioned_user_ids: [user.id]
      end
    end
  end

  test "should send topic reply notification to followers" do
    u1 = create(:user)
    u2 = create(:user)
    t = create(:topic)

    # 正常状况
    perform_enqueued_jobs do
      u1.follow_topic(t)
      u2.follow_topic(t)
      assert_changes -> { u1.notifications.count }, 1 do
        create :reply, topic: t, user: user
      end
    end

    # TODO: 需要更多的测试，测试 @ 并且有关注的时候不会重复通知，回复时候不会通知自己
  end

  test "Touch Topic in callback" do
    topic = create :topic, updated_at: 1.days.ago
    reply = create :reply, topic: topic

    # should update Topic updated_at on Reply updated
    old_updated_at = topic.updated_at
    reply.body = "foobar"
    reply.save
    refute_equal old_updated_at, topic.updated_at

    # should update Topic updated_at on Reply deleted
    old_updated_at = topic.updated_at
    reply.body = "foobar"
    reply.destroy
    refute_equal old_updated_at, topic.updated_at

    # system reply
    target = create(:topic)

    # should not change topic last_replied_at when reply created
    topic = create(:topic, replied_at: 1.days.ago, last_active_mark: 1.days.ago.to_i)
    system_reply = build(:reply, action: "mention", topic: topic, target: target)
    old_last_active_mark = topic.last_active_mark
    old_replied_at = topic.replied_at
    topic.stubs(:update_last_reply).returns(true)
    system_reply.save
    assert_equal false, system_reply.new_record?
    topic.reload
    assert_equal old_last_active_mark, topic.last_active_mark
    assert_equal old_replied_at.to_i, topic.replied_at.to_i
  end

  test "ban words for Reply body" do
    topic = create(:topic)

    Setting.stub(:ban_words_on_reply, %w[mark 顶]) do
      assert_equal 1, topic.replies.create(body: "顶", user: user).errors[:body].size
      assert_equal 1, topic.replies.create(body: "mark", user: user).errors[:body].size
      assert_equal 1, topic.replies.create(body: " mark ", user: user).errors[:body].size
      assert_equal 1, topic.replies.create(body: "MARK", user: user).errors[:body].size
      assert_equal 1, topic.replies.create(body: "mark1", user: user).errors[:body].size
      assert_equal 1, topic.replies.create(body: "请顶一下", user: user).errors[:body].size
      assert_equal 0, topic.replies.create(body: "thanks", user: user).errors[:body].size
    end

    Setting.stub(:ban_words_on_reply, []) do
      t = topic.replies.create(body: "mark", user: user)
      assert_equal 0, t.errors[:body].size
    end
  end

  test "ban words should not for system event Reply" do
    topic = create(:topic)

    Setting.stub(:ban_words_on_reply, [""]) do
      assert_nothing_raised do
        Reply.create_system_event!(action: "excellent", topic_id: topic.id)
      end
    end
  end

  test "after_destroy" do
    # should call topic.update_deleted_last_reply
    r = create(:reply)
    r.topic.expects(:update_deleted_last_reply).with(r).once
    r.destroy
  end

  test "upvote?" do
    reply = build :reply

    chars = %w[+1 :+1: :thumbsup: :plus1: 👍 👍🏻 👍🏼 👍🏽 👍🏾 👍🏿]

    chars.each do |key|
      reply.body = key
      assert_equal true, reply.upvote?
    end

    reply.body = "Ok +1"
    assert_equal false, reply.upvote?
  end

  test ".check_vote_chars_for_like_topic" do
    user = create :user
    topic = create :topic
    reply = build :reply, user: user, topic: topic

    # UpVote
    user.expects(:like).with(topic).once
    reply.stubs(:upvote?).returns(true)
    reply.send(:check_vote_chars_for_like_topic)

    # None
    user.expects(:like).with(topic).at_most(0)
    reply.stubs(:upvote?).returns(false)
    reply.send(:check_vote_chars_for_like_topic)

    # callback on created
    reply.expects(:check_vote_chars_for_like_topic).once
    reply.save
  end

  test "#broadcast_to_client" do
    reply = create(:reply)

    args = ["topics/#{reply.topic_id}/replies", {id: reply.id, user_id: reply.user_id, action: :create}]
    ActionCable.server.expects(:broadcast).with(*args).once
    reply.broadcast_to_client
  end

  test "#create_system_event!" do
    # should create system event with empty body
    Current.stubs(:user).returns(user)
    topic = create :topic
    reply = Reply.create_system_event!(topic: topic, action: "bbb")
    assert_equal false, reply.new_record?
    assert_equal true, reply.system_event?
    assert_equal false, reply.new_record?
  end

  test ".default_notification" do
    reply = create(:reply, topic: create(:topic))
    t = Time.now

    val = {
      notify_type: "topic_reply",
      target_type: "Reply", target_id: reply.id,
      second_target_type: "Topic", second_target_id: reply.topic_id,
      actor_id: reply.user_id,
      created_at: t,
      updated_at: t
    }

    Time.stub(:now, t) do
      assert_equal val, reply.default_notification
    end
  end

  test ".notification_receiver_ids" do
    mentioned_user_ids = [1, 2, 3]
    user = create(:user)
    topic = create(:topic, user_id: 10)
    reply = create(:reply, user: user, topic: topic, mentioned_user_ids: mentioned_user_ids)

    topic.stubs(:follow_by_user_ids).returns([1, 3, 7, 11, 12, 14, user.id])
    user.stubs(:follow_by_user_ids).returns([2, 3, 5, 7, 9])

    assert_kind_of Array, reply.notification_receiver_ids

    # should not include mentioned_user_ids
    assert_not_includes_any reply.notification_receiver_ids, *reply.mentioned_user_ids

    # should include topic follower and topic author
    assert_includes_all reply.notification_receiver_ids, 10
    assert_includes_all reply.notification_receiver_ids, 7, 11, 12, 14

    # should not include reply user_id
    assert_not_includes_any reply.notification_receiver_ids, user.id

    # should include replyer followers
    assert_includes_all reply.notification_receiver_ids, 5, 7, 9

    # should removed duplicate
    assert_equal reply.notification_receiver_ids.uniq, reply.notification_receiver_ids
  end

  test "RateLimit should limit by interval" do
    Setting.stubs(:reply_create_limit_interval).returns(60)
    reply = build(:reply, user: user)
    assert_equal true, reply.save
    assert_equal 1, Rails.cache.read("users:#{user.id}:reply-create")
    assert_equal 1, Rails.cache.read("users:#{user.id}:reply-create-by-hour")

    reply = build(:reply, user: user)
    assert_equal false, reply.save
    assert_equal ["Reply too frequently, please try again later."], reply.errors.messages_for(:base)

    Rails.cache.delete("users:#{user.id}:reply-create")
    Setting.stubs(:reply_create_limit_interval).returns(0)
    reply = build(:reply, user: user)
    reply.save!
    assert_nil Rails.cache.read("users:#{user.id}:reply-create")
  end

  test "RateLimit should limit by hour" do
    create(:reply, user: user)
    count = Rails.cache.read("users:#{user.id}:reply-create-by-hour")
    assert_equal 1, count

    create(:reply, user: user)
    count = Rails.cache.read("users:#{user.id}:reply-create-by-hour")
    assert_equal 2, count

    Setting.stubs(:reply_create_hour_limit_count).returns(10)
    Rails.cache.write("users:#{user.id}:reply-create-by-hour", 10)
    reply = build(:reply, user: user)
    assert_equal false, reply.save
    assert_equal ["Creation has been rejected by limit 10 replies created within 1 hour."], reply.errors.messages_for(:base)

    Setting.stubs(:reply_create_hour_limit_count).returns(0)
    reply = build(:reply, user: user)
    reply.save!
  end

  test "RateLimit should be stricter for newbies" do
    Setting.stubs(:newbie_limit_time).returns(1.day.to_i)
    Setting.stubs(:reply_create_limit_interval).returns(0)
    Setting.stubs(:reply_create_hour_limit_count).returns(10)

    newbie = create(:user, created_at: 1.hour.ago)
    Rails.cache.write("users:#{newbie.id}:reply-create-by-hour", 5)
    reply = build(:reply, user: newbie)
    assert_equal false, reply.save
    assert_equal ["Creation has been rejected by limit 5 replies created within 1 hour."], reply.errors.messages_for(:base)

    member = create(:user, created_at: 2.days.ago)
    Rails.cache.write("users:#{member.id}:reply-create-by-hour", 5)
    reply = build(:reply, user: member)
    assert_equal true, reply.save
  end

  test "RateLimit should skip admin" do
    Setting.stubs(:reply_create_limit_interval).returns(60)
    Setting.stubs(:reply_create_hour_limit_count).returns(1)

    admin = create(:admin)
    assert create(:reply, user: admin)
    assert create(:reply, user: admin)
    assert_nil Rails.cache.read("users:#{admin.id}:reply-create")
  end

  test "RateLimit should skip system event replies" do
    Setting.stubs(:reply_create_limit_interval).returns(60)
    topic = create(:topic)
    assert_nothing_raised do
      Reply.create_system_event!(action: "excellent", topic_id: topic.id, user: user)
    end
    assert_nil Rails.cache.read("users:#{user.id}:reply-create")
  end
end
