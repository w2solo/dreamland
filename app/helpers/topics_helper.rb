# frozen_string_literal: true

require "digest/md5"
module TopicsHelper
  def topic_favorite_tag(topic, opts = {})
    return "" if current_user.blank?
    opts[:class] ||= ""
    class_name = ""
    link_title = t("common.favorite")
    if current_user&.favorite_topic?(topic)
      class_name = "active"
      link_title = t("common.unfavorite")
    end

    if opts[:class].present?
      class_name += " " + opts[:class]
    end

    link_to(icon_tag("bookmark"), "#", :title => link_title, :class => "bookmark #{class_name}", "data-id" => topic.id)
  end

  def topic_follow_tag(topic, opts = {})
    return "" if current_user.blank?
    return "" if topic.blank?
    return "" if owner?(topic)
    opts[:class] ||= ""
    class_name = "follow"
    class_name += " active" if current_user.follow_topic?(topic)
    if opts[:class].present?
      class_name += " " + opts[:class]
    end
    link_to(icon_tag("bell"), "#", :title => t("common.subscribe"), "data-id" => topic.id, :class => class_name)
  end

  def topic_title_tag(topic, opts = {})
    return t("topics.topic_was_deleted") if topic.blank?
    if opts[:reply]
      index = topic.floor_of_reply(opts[:reply])
      path = main_app.topic_path(topic, anchor: "reply#{index}")
    else
      path = main_app.topic_path(topic)
    end
    link_to(topic.title, path, title: topic.title, class: "topic-title")
  end

  def topic_excellent_tag(topic)
    return "" unless topic.excellent?
    icon_tag("award")
  end

  def topic_close_tag(topic)
    return "" unless topic.closed?
    content_tag(:i, "", title: t("topics.closed_tooltip"), class: "fa fa-check-circle", data: {toggle: "tooltip"})
  end

  def topic_intent_placeholder(intent)
    case intent.to_s
    when "review"
      t("topics.intent.review_placeholder")
    when "help"
      t("topics.intent.help_placeholder")
    end
  end

  def topic_compose_node_id
    return if @node.blank?
    return if @node.id == Setting.product_node_id.to_i
    @node.id
  end

  def render_node_name(node)
    return "" if node.blank?
    link_to(node.name, main_app.node_topics_path(node.id), class: "node")
  end
end
