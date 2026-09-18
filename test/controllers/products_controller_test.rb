# frozen_string_literal: true

require "spec_helper"

describe ProductsController do
  let(:user) { create :user }
  let(:newbie) { create :newbie }
  let(:cover) { fixture_file_upload("cover.png", "image/png") }

  setup do
    Setting.stubs(:ban_words_in_body).returns([])
    Setting.stubs(:product_node_id).returns(9)
  end

  describe "GET /products" do
    it "renders product cards" do
      product = create(:product, user: user)
      get products_path
      assert_equal 200, response.status
      assert_includes response.body, product.name
    end
  end

  describe "GET /topics/newproduct" do
    it "redirects to products" do
      get newproduct_topics_path
      assert_redirected_to products_path
    end
  end

  describe "GET /products/new" do
    it "requires login" do
      get new_product_path
      refute_equal 200, response.status
    end

    it "allows members" do
      sign_in user
      get new_product_path
      assert_equal 200, response.status
      assert_includes response.body, "product-cover-input"
    end

    it "rejects newbies" do
      Setting.stubs(:newbie_limit_time).returns("100000")
      sign_in newbie
      get new_product_path
      refute_equal 200, response.status
    end
  end

  describe "POST /products" do
    it "creates product and topic" do
      sign_in user
      user.stubs(:change_score)
      assert_difference %w[Product.count Topic.count], 1 do
        post products_path, params: {
          product: {
            name: "TinySnap",
            tagline: "Capture anything",
            url: "https://tinysnap.example",
            status: "shipped",
            body: "We built a screenshot tool.",
            cover: cover
          }
        }
      end
      product = Product.last
      assert_redirected_to topic_path(product.topic)
      assert_equal "TinySnap", product.topic.title
    end

    it "rejects missing url" do
      sign_in user
      assert_no_difference "Product.count" do
        post products_path, params: {
          product: {
            name: "No URL",
            tagline: "Nope",
            url: "",
            status: "shipped",
            body: "Story",
            cover: cover
          }
        }
      end
      assert_equal 200, response.status
    end
  end
end
