# frozen_string_literal: true

class Product < ApplicationRecord
  URL_REGEXP = %r{\Ahttps?://.+}i.freeze
  IMAGE_URL_REGEXP = %r{\.(?:png|jpe?g|gif|webp)(?:\?.*)?\z}i.freeze
  MARKDOWN_IMAGE_REGEXP = %r{!\[[^\]]*\]\((https?://[^)\s]+)\)}i.freeze
  HTML_IMAGE_REGEXP = %r{<img[^>]+src=["'](https?://[^"']+)["']}i.freeze
  BARE_URL_REGEXP = %r{https?://[^\s)\]>'"]+}i.freeze

  belongs_to :user, required: true
  belongs_to :topic, optional: true, touch: true

  mount_uploader :cover, CoverUploader

  enum status: {building: 0, shipped: 1, sunset: 2}

  attr_accessor :body

  validates :name, presence: true, length: {maximum: 40}
  validates :tagline, length: {maximum: 80}
  validates :tagline, presence: true, on: :launch
  validates :url, presence: true, on: :launch
  validates :url, format: {with: URL_REGEXP, message: :invalid_product_url}, allow_blank: true
  validates :cover, presence: true, on: :launch, if: :cover_required?
  validates :body, presence: true, on: :launch, if: :body_required?
  validate :url_unique_for_user
  validate :check_ban_words

  # Only products whose topic is still public. Inner join so soft-deleted
  # topics never appear on the homepage / 造船台.
  scope :launched, -> {
    where.not(topic_id: nil)
      .joins(:topic)
      .merge(Topic.without_ban)
  }
  # topic_id 还在，但主题已被软删或物理删除
  scope :orphaned, -> { where.not(topic_id: nil).left_joins(:topic).where(topics: {id: nil}) }
  scope :by_launch, -> { order(Arel.sql("#{table_name}.launched_at DESC NULLS LAST, #{table_name}.id DESC")) }

  def self.this_week
    range = Time.zone.now.beginning_of_week..Time.zone.now.end_of_week
    launched.where(launched_at: range).by_launch
  end

  def self.for_week(beginning, ending)
    launched.where(launched_at: beginning.beginning_of_day..ending.end_of_day).by_launch
  end

  def self.backfill_from_node!
    node_id = Setting.product_node_id.to_i
    node = Node.find_by(id: node_id)
    return 0 if node.blank?

    url_regexp = %r{https?://[^\s)\]>]+}i
    created = 0

    Topic.unscoped.where(node_id: node.id, deleted_at: nil).find_each do |topic|
      next if topic.user_id.blank?

      if (existing = find_by(topic_id: topic.id))
        if existing.cover.blank?
          existing.assign_cover_from_body(topic.body)
          existing.save
        end
        next
      end

      product = new(
        user_id: topic.user_id,
        topic_id: topic.id,
        name: topic.title.to_s.truncate(40, omission: ""),
        url: topic.body.to_s.scan(url_regexp).find { |candidate| !image_url?(candidate) },
        status: :shipped,
        launched_at: topic.created_at
      )
      product.assign_cover_from_body(topic.body)
      created += 1 if product.save
    end

    created
  end

  def self.first_image_url(body)
    text = body.to_s
    markdown_url = text[MARKDOWN_IMAGE_REGEXP, 1]
    return markdown_url if image_url?(markdown_url)

    html_url = text[HTML_IMAGE_REGEXP, 1]
    return html_url if image_url?(html_url)

    text.scan(BARE_URL_REGEXP).find { |url| image_url?(url) }
  end

  def self.image_url?(url)
    url.present? && url.match?(IMAGE_URL_REGEXP)
  end

  def visit_url?
    url.present? && url.match?(URL_REGEXP)
  end

  def name_initial
    name.to_s.gsub(/[\p{P}\p{S}]+/, "").chars.find { |char| char.match?(/[\p{L}\p{N}]/) } || name.to_s.strip[0]
  end

  def assign_cover_from_body(body)
    return if cover.present?

    image_url = self.class.first_image_url(body)
    return if image_url.blank?

    self.remote_cover_url = image_url
  rescue StandardError
    self.remote_cover_url = nil
  end

  def cover_required?
    new_record? || cover.blank?
  end

  def body_required?
    new_record? || body.present? || topic.blank?
  end

  def publish
    return false unless valid?(:launch)

    transaction do
      node = Node.find_builtin_node(Setting.product_node_id.to_i, "我的作品")
      launch_topic = Topic.new(
        user: user,
        node: node,
        title: name,
        body: body
      )
      unless launch_topic.save
        copy_topic_errors(launch_topic)
        raise ActiveRecord::Rollback
      end

      self.topic = launch_topic
      self.launched_at ||= Time.current
      unless save
        raise ActiveRecord::Rollback
      end

      user.change_score(:create_product)
    end

    errors.empty? && persisted? && topic_id.present?
  end

  def update_launch(attrs)
    story = attrs.delete(:body)
    assign_attributes(attrs)
    self.body = story unless story.nil?

    return false unless valid?(:launch)

    transaction do
      save!
      if topic
        topic_attrs = {title: name}
        topic_attrs[:body] = story if story.present?
        topic.update!(topic_attrs)
      end
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def path
    topic.present? ? url_helpers.topic_path(topic) : url_helpers.product_path(self)
  end

  private

  def url_unique_for_user
    return if url.blank? || user_id.blank?

    scope = Product.where(user_id: user_id, url: url)
    scope = scope.where.not(id: id) if persisted?
    errors.add(:url, :taken) if scope.exists?
  end

  def check_ban_words
    ban_words = Setting.ban_words_in_body.collect(&:strip).reject(&:blank?)
    %i[name tagline url].each do |field|
      value = public_send(field).to_s
      ban_words.each do |word|
        next if word.blank?
        if value.include?(word)
          errors.add(field, I18n.t("topics.sensitive_word_limit", word: word))
          return
        end
      end
    end
  end

  def copy_topic_errors(launch_topic)
    launch_topic.errors.full_messages.each do |message|
      errors.add(:base, message)
    end
  end
end
