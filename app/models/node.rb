# frozen_string_literal: true

class Node < ApplicationRecord
  second_level_cache expires_in: 2.weeks

  has_many :topics

  validates :name, presence: true
  validates :name, uniqueness: true

  scope :hots, -> { order(topics_count: :desc) }
  scope :sorted, -> { order(sort: :desc) }

  form_select :name

  def self.topic_form_options
    sorted.where.not(id: Setting.product_node_id.to_i).name_options
  end

  def self.suggested_for_intent(intent)
    names = {
      "review" => %w[心得总结 复盘],
      "help" => %w[聊天讨论 求助]
    }[intent.to_s]
    return if names.blank?

    names.each do |name|
      node = find_by(name: name)
      return node if node
    end
    nil
  end

  def self.find_builtin_node(id, name)
    node = find_by_id(id)
    return node if node
    create(id: id, name: name)
  end

  def collapse_summary?
    @collapse_summary ||= summary_html.scan(/<p>|<ul>/).size > 2
  end

  def summary_html
    Rails.cache.fetch("#{cache_key_with_version}/summary_html") do
      Homeland::Markdown.call(summary || "")
    end
  end
end
