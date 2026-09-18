# frozen_string_literal: true

require "test_helper"

class WeeklyDigestTest < ActiveSupport::TestCase
  setup do
    Setting.stubs(:ban_words_in_body).returns([])
    @user = create(:user)
  end

  test "find current week" do
    digest = WeeklyDigest.current
    product = create(:product, user: @user, launched_at: Time.zone.now)
    assert_includes digest.products, product
  end

  test "find by year-week id" do
    date = Date.commercial(2025, 3)
    product = create(:product, user: @user, launched_at: date.to_time)
    digest = WeeklyDigest.find("2025-w03")
    assert_equal date.beginning_of_week, digest.beginning
    assert_includes digest.products.map(&:id), product.id
  end

  test "invalid id raises not found" do
    assert_raises(ActiveRecord::RecordNotFound) { WeeklyDigest.find("nope") }
  end

  test "mailer sends digest" do
    create(:product, user: @user, launched_at: Time.zone.now)
    email = UserMailer.weekly_digest(@user.id, WeeklyDigest.current.to_param)
    assert_equal [@user.email], email.to
    assert_includes email.body.encoded, @user.products.first.name
  end
end
