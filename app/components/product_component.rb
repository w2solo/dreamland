# frozen_string_literal: true

class ProductComponent < ApplicationComponent
  attr_reader :product, :variant

  delegate :timeago, to: :helpers

  with_collection_parameter :product

  def initialize(product:, variant: "card")
    @product = product
    @variant = variant
  end

  def render?
    !!@product
  end

  def compact?
    variant.to_s == "compact"
  end

  def topic
    product.topic
  end

  def likes_count
    topic&.likes_count.to_i
  end

  def replies_count
    topic&.replies_count.to_i
  end
end
