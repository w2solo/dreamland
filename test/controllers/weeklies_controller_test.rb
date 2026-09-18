# frozen_string_literal: true

require "spec_helper"

describe WeekliesController do
  let(:user) { create :user }

  setup do
    Setting.stubs(:ban_words_in_body).returns([])
  end

  describe "GET /weekly" do
    it "shows this week products" do
      product = create(:product, user: user, launched_at: Time.zone.now)
      get weekly_path
      assert_equal 200, response.status
      assert_includes response.body, product.name
    end

    it "renders rss" do
      create(:product, user: user, launched_at: Time.zone.now)
      get weekly_path(format: :rss)
      assert_equal 200, response.status
      assert_includes response.body, "<rss"
    end
  end

  describe "GET /weekly/:id" do
    it "shows a historical week" do
      date = Date.commercial(2024, 10)
      product = create(:product, user: user, launched_at: date.to_time)
      get weekly_issue_path("2024-w10")
      assert_equal 200, response.status
      assert_includes response.body, product.name
    end
  end
end
