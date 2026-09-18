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

  test "first_image_url prefers markdown image over product link" do
    body = "Try https://old.example/app please\n\n![cover](https://cdn.example/shot.png)"
    assert_equal "https://cdn.example/shot.png", Product.first_image_url(body)
  end

  test "name_initial skips leading punctuation" do
    product = build(:product, name: "[完全免费] Reddit tool")
    assert_equal "完", product.name_initial
  end

  test "backfill assigns remote cover from first topic image" do
    node = Node.find_builtin_node(9, "我的作品")
    Setting.stubs(:product_node_id).returns(node.id)
    create(:topic, user: @user, node: node, title: "Ship", body: "Go https://ship.example\n![shot](https://cdn.example/shot.png)")
    Product.any_instance.expects(:remote_cover_url=).with("https://cdn.example/shot.png")
    assert_equal 1, Product.backfill_from_node!
  end

  test "destroying a topic also destroys its product" do
    product = create(:product, user: @user)
    product.topic.destroy
    refute Product.exists?(product.id)
  end

  test "orphaned includes products whose topics were deleted" do
    visible = create(:product, user: @user)
    hidden = create(:product, user: @user)
    hidden.topic.update_columns(deleted_at: Time.current)

    ids = Product.orphaned.map(&:id)
    assert_includes ids, hidden.id
    refute_includes ids, visible.id
  end

  test "this_week excludes products whose topics were deleted" do
    visible = create(:product, user: @user, name: "Visible Ship")
    hidden = create(:product, user: @user, name: "Deleted Ship")
    hidden.topic.update_columns(deleted_at: Time.current)

    ids = Product.this_week.map(&:id)
    assert_includes ids, visible.id
    refute_includes ids, hidden.id
  end

  test "this_week excludes products whose topics were banned" do
    visible = create(:product, user: @user, name: "Normal Ship")
    banned = create(:product, user: @user, name: "Banned Ship")
    banned.topic.update!(grade: :ban)

    ids = Product.this_week.map(&:id)
    assert_includes ids, visible.id
    refute_includes ids, banned.id
  end

  test "backfill fills cover on existing products without cover" do
    node = Node.find_builtin_node(9, "我的作品")
    Setting.stubs(:product_node_id).returns(node.id)
    topic = create(:topic, user: @user, node: node, title: "Old Ship", body: "https://old.example/app ![x](https://cdn.example/a.png)")
    create(:product, user: @user, topic: topic, cover: nil)
    Product.any_instance.expects(:remote_cover_url=).with("https://cdn.example/a.png")
    assert_equal 0, Product.backfill_from_node!
  end
end
