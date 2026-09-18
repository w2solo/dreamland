# frozen_string_literal: true

require "spec_helper"

describe HomeController do
  let(:user) { create :user }

  setup do
    Setting.stubs(:ban_words_in_body).returns([])
  end

  describe "GET /sitemap.xml" do
    it "includes products and recent topics" do
      product = create(:product, user: user)
      topic = create(:topic, user: user)
      get sitemap_path
      assert_equal 200, response.status
      assert_includes response.body, topic_url(product.topic)
      assert_includes response.body, topic_url(topic)
    end
  end
end

describe TopicsController do
  let(:user) { create :user }

  setup do
    Setting.stubs(:ban_words_in_body).returns([])
  end

  describe "GET /topics/new intents" do
    it "shows intent picker" do
      sign_in user
      get new_topic_path
      assert_equal 200, response.status
      assert_includes response.body, I18n.t("topics.intent.product")
    end

    it "redirects product node to launch form" do
      sign_in user
      Setting.stubs(:product_node_id).returns(9)
      get new_topic_path, params: {node: 9}
      assert_redirected_to new_product_path
    end

    it "shows form for chat intent" do
      sign_in user
      get new_topic_path, params: {intent: "chat"}
      assert_equal 200, response.status
      assert_includes response.body, 'tb="edit-topic"'
    end
  end

  describe "GET /topics" do
    it "renders weekly products as cards" do
      product = create(:product, user: user)
      get topics_path
      assert_equal 200, response.status
      assert_includes response.body, "product-card-card"
      assert_includes response.body, product.name
      refute_includes response.body, "sidebar-products"
    end

    it "shows at most 4 weekly products" do
      5.times { |i| create(:product, user: user, name: "Ship #{i}") }
      get topics_path
      assert_equal 200, response.status
      assert_equal 4, response.body.scan("product-card-card").size
    end

    it "does not render products whose topics were deleted" do
      create(:product, user: user, name: "Keep Ship")
      hidden = create(:product, user: user, name: "Gone Ship")
      hidden.topic.update_columns(deleted_at: Time.current)

      get topics_path
      assert_equal 200, response.status
      assert_includes response.body, "Keep Ship"
      refute_includes response.body, "Gone Ship"
    end
  end
end

describe SettingsController do
  let(:user) { create :user }

  describe "GET /setting/weekly_digest/unsubscribe" do
    it "turns off digest without login" do
      token = user.weekly_digest_token
      get unsubscribe_weekly_digest_path, params: {token: token}
      assert_redirected_to root_path
      assert_equal false, user.reload.weekly_digest?
    end
  end
end
