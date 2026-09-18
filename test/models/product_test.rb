# frozen_string_literal: true

require "test_helper"

class ProductTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    Setting.stubs(:ban_words_in_body).returns([])
    Setting.stubs(:product_node_id).returns(9)
  end

  test "launch context requires cover url tagline and body" do
    product = @user.products.new(name: "Solo", status: :shipped)
    refute product.valid?(:launch)
    assert product.errors[:url].present?
    assert product.errors[:tagline].present?
    assert product.errors[:cover].present?
    assert product.errors[:body].present?
  end

  test "url must be http or https" do
    product = build(:product, user: @user, url: "ftp://example.com")
    refute product.valid?
    assert product.errors[:url].present?
  end

  test "url unique per user" do
    create(:product, user: @user, url: "https://example.com/app")
    duplicate = build(:product, user: @user, url: "https://example.com/app")
    refute duplicate.valid?
    assert duplicate.errors[:url].present?
  end

  test "publish creates topic without create_topic score" do
    product = build(:product, user: @user, topic: nil, launched_at: nil)
    product.body = "Here is the story of this product."
    @user.expects(:change_score).with(:create_product).once
    @user.expects(:change_score).with(:create_topic).never

    assert product.publish
    product.reload
    assert product.topic.present?
    assert_equal product.name, product.topic.title
    assert_equal Setting.product_node_id.to_i, product.topic.node_id
    assert_equal "Here is the story of this product.", product.topic.body
  end

  test "visit_url? requires http url" do
    product = build(:product, url: nil)
    refute product.visit_url?
    product.url = "https://ok.com"
    assert product.visit_url?
  end

  test "backfill_from_node! creates products from existing topics" do
    node = Node.find_builtin_node(9, "我的作品")
    Setting.stubs(:product_node_id).returns(node.id)
    topic = create(:topic, user: @user, node: node, title: "Old Ship", body: "Try https://old.example/app please")
    assert_equal 1, Product.backfill_from_node!
    product = Product.find_by(topic_id: topic.id)
    assert_equal "Old Ship", product.name
    assert_equal "https://old.example/app", product.url
    assert_equal 0, Product.backfill_from_node!
  end
end
