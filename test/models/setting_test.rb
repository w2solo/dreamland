# frozen_string_literal: true

require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "navbar_brand_html" do
    assert_equal %(<a href="/" class="navbar-brand"><b>#{Setting.app_name}</b></a>), Setting.navbar_brand_html
  end

  test "reject_newbie_reply_in_the_evening" do
    assert_equal true, Setting.reject_newbie_reply_in_the_evening
    assert_equal true, Setting.reject_newbie_reply_in_the_evening?
  end

  test "topic_create_rate_limit" do
    assert_equal false, Setting.topic_create_rate_limit
    assert_equal false, Setting.topic_create_rate_limit?
  end

  test "default_locale" do
    assert_equal "en", Setting.default_locale
  end

  test "auto_locale" do
    assert_equal false, Setting.auto_locale
  end

  test "ban_reasons" do
    assert_equal ["标题或正文描述不清楚"], Setting.ban_reasons
  end

  test "ban_reason_html" do
    assert_equal "此贴因内容原因不符合要求，被管理员屏蔽，请根据管理员给出的原因进行调整", Setting.ban_reason_html
  end

  test "protocol" do
    assert_equal "http", Setting.protocol
    Rails.env.stub(:production?, true) do
      assert_equal "https", Setting.protocol
    end
  end

  test "domain" do
    assert_equal "localhost", Setting.safe_domain

    ENV["domain"] = "ruby-china.org"
    assert_equal "ruby-china.org", Setting.safe_domain

    ENV["domain"] = "*.ruby-china.org"
    assert_equal "ruby-china.org", Setting.safe_domain

    ENV["domain"] = "*.ruby-china.org,www.ruby-china.org"
    assert_equal "ruby-china.org", Setting.safe_domain

    ENV["domain"] = "www.ruby-china.org,*.ruby-china.org"
    assert_equal "www.ruby-china.org", Setting.safe_domain
  end

  test "base_url" do
    Setting.stubs(:domain).returns("homeland.io")
    Setting.stub(:protocol, "https") do
      assert_equal "https://homeland.io", Setting.base_url
    end

    Rails.env.stub(:development?, true) do
      assert_equal "http://localhost:3000", Setting.base_url
    end
  end

  test "admin_emails" do
    assert_equal ["admin@admin.com"], Setting.admin_emails
    Setting.admin_emails = "admin@admin.com a0@foo.com\r\na1@foo.com\na2@foo.com\ra3@foo.com,a4@foo.com"
    assert_equal ["admin@admin.com", "a0@foo.com", "a1@foo.com", "a2@foo.com", "a3@foo.com", "a4@foo.com"], Setting.admin_emails
  end

  test "modules" do
    Setting.stubs(:modules).returns("all")
    assert_equal true, Setting.has_module?("foo")
    assert_equal true, Setting.has_module?("home")
    assert_equal true, Setting.has_module?("topic")
    Setting.stubs(:modules).returns(["home", "topic\n", "team "])
    assert_equal true, Setting.has_module?("home")
    assert_equal true, Setting.has_module?("topic")
    assert_equal true, Setting.has_module?("team")
    assert_equal false, Setting.has_module?("bbb")
  end

  test "sorted_plugins" do
    Setting.sorted_plugins = "press,wiki,note,jobs"
    assert_equal %w[press wiki note jobs], Setting.sorted_plugins
  end

  test "profile_fields" do
    Setting.stubs(:profile_fields).returns("all")
    assert_equal true, Setting.has_profile_field?("foo")
    assert_equal true, Setting.has_profile_field?("weibo")
    assert_equal true, Setting.has_profile_field?("douban")
    Setting.stubs(:profile_fields).returns(["weibo", "facebook\n", "douban ", "qq"])
    assert_equal true, Setting.has_profile_field?("weibo")
    assert_equal true, Setting.has_profile_field?("facebook")
    assert_equal true, Setting.has_profile_field?("douban")
    assert_equal true, Setting.has_profile_field?("qq")
    assert_equal false, Setting.has_profile_field?("ccc")
  end

  test "sso_provider_enabled" do
    assert_equal false, Setting.sso_provider_enabled?
  end

  test "sso_enabled" do
    assert_equal false, Setting.sso_enabled?
  end

  test "allow_change_login" do
    assert_equal false, Setting.allow_change_login?
    Setting.allow_change_login = "true"
    assert_equal true, Setting.allow_change_login?
  end

  test "twitter_id" do
    Setting.twitter_id = "ruby_china"
    assert_equal "ruby_china", Setting.twitter_id
  end

  test "node_ids_hide_in_topics_index" do
    Setting.node_ids_hide_in_topics_index = <<~LINES
      100
      101,102,103
    LINES
    assert_equal %w[100 101 102 103], Setting.node_ids_hide_in_topics_index
  end

  test "blacklist_ips" do
    Setting.blacklist_ips = <<~LINES
      10.10.10.10
      11.11.11.11,12.12.12.12
    LINES
    assert_equal ["10.10.10.10", "11.11.11.11", "12.12.12.12"], Setting.blacklist_ips
  end

  test "ban_words_on_reply" do
    Setting.ban_words_on_reply = <<~LINES
      This is first line.
      And, this is second line.
    LINES
    assert_equal ["This is first line.", "And, this is second line."], Setting.ban_words_on_reply
  end

  test "tips" do
    Setting.tips = <<~LINES
      This is first line.
      And, this is second line.
    LINES
    assert_equal ["This is first line.", "And, this is second line."], Setting.tips
  end

  test "share_allow_sites" do
    Setting.share_allow_sites = <<~LINES
      weibo
      facebook
      twitter
    LINES
    assert_equal ["weibo", "facebook", "twitter"], Setting.share_allow_sites
  end

  test "editor_languages" do
    Setting.editor_languages = <<~LINES
      rb
      html
      js
    LINES

    assert_equal ["rb", "html", "js"], Setting.editor_languages
  end

  test "has_omniauth?" do
    assert_equal true, Setting.has_omniauth?(:github)
    assert_equal true, Setting.has_omniauth?(:twitter)
    assert_equal true, Setting.has_omniauth?(:wechat)
    assert_equal false, Setting.has_omniauth?(:google)
  end

  test ".require_restart?" do
    setting = Setting.new(var: "app_name")
    assert_equal true, setting.require_restart?

    setting = Setting.new(var: "admin_emails")
    assert_equal false, setting.require_restart?
  end

  test "cable_allowed_request_origin" do
    Setting.stub(:domain, "localhost") do
      assert_equal false, Setting.cable_allowed_request_origin.match?("http://foobar.com")
      assert_equal false, Setting.cable_allowed_request_origin.match?("http://foobar.com:80")
      assert_equal true, Setting.cable_allowed_request_origin.match?("http://localhost")
      assert_equal true, Setting.cable_allowed_request_origin.match?("https://localhost")
      assert_equal true, Setting.cable_allowed_request_origin.match?("http://localhost:3000")
      assert_equal true, Setting.cable_allowed_request_origin.match?("https://localhost:3000")
    end
    Setting.stub(:domain, "www.foo.com") do
      assert_equal false, Setting.cable_allowed_request_origin.match?("http://foobar.com")
      assert_equal false, Setting.cable_allowed_request_origin.match?("http://foobar.com:80")
      assert_equal true, Setting.cable_allowed_request_origin.match?("http://www.foo.com")
      assert_equal true, Setting.cable_allowed_request_origin.match?("https://www.foo.com")
      assert_equal true, Setting.cable_allowed_request_origin.match?("http://www.foo.com:3000")
      assert_equal true, Setting.cable_allowed_request_origin.match?("https://www.foo.com:3000")
    end
  end

  test "imageproxy_ignore_hosts" do
    Setting.stub(:upload_url, "https://bar.com") do
      assert_equal ["bar.com", "localhost"], Setting.imageproxy_ignore_hosts

      Setting.stub(:asset_host, "https://asset.bar.com") do
        assert_equal ["bar.com", "asset.bar.com", "localhost"], Setting.imageproxy_ignore_hosts
      end
    end
  end

  test "anti-spam field defaults" do
    assert_equal 1.day.to_i, Setting.get_field(:newbie_limit_time)[:default]
    assert_equal 60, Setting.get_field(:topic_create_limit_interval)[:default]
    assert_equal 8, Setting.get_field(:topic_create_hour_limit_count)[:default]
    assert_equal 10, Setting.get_field(:reply_create_limit_interval)[:default]
    assert_equal 30, Setting.get_field(:reply_create_hour_limit_count)[:default]
    assert_equal 5, Setting.get_field(:sign_up_daily_limit)[:default]
    assert_equal true, Setting.get_field(:captcha_enable)[:default]
    assert_equal 300, Setting.get_field(:rack_attack)[:default][:limit]
    assert_equal 300, Setting.get_field(:rack_attack)[:default][:period]
  end

  test "apply_anti_spam_defaults! fills blank values only" do
    Setting.unstub(:newbie_limit_time)
    Setting.unstub(:topic_create_limit_interval)
    Setting.unstub(:topic_create_hour_limit_count)
    Setting.unstub(:sign_up_daily_limit)
    Setting.unstub(:captcha_enable?)
    Setting.unstub(:rack_attack_limit)

    Setting.newbie_limit_time = 3600
    Setting.topic_create_limit_interval = 15
    Setting.topic_create_hour_limit_count = 3
    Setting.sign_up_daily_limit = 2
    Setting.captcha_enable = false
    Setting.reject_newbie_reply_in_the_evening = false
    Setting.rack_attack = {limit: 0, period: 60}

    Setting.apply_anti_spam_defaults!

    assert_equal 3600, Setting.newbie_limit_time
    assert_equal 15, Setting.topic_create_limit_interval
    assert_equal 3, Setting.topic_create_hour_limit_count
    assert_equal 2, Setting.sign_up_daily_limit
    assert_equal true, Setting.captcha_enable?
    assert_equal true, Setting.reject_newbie_reply_in_the_evening?
    assert_equal 300, Setting.rack_attack_limit
    assert_equal 300, Setting.rack_attack_period

    Setting.newbie_limit_time = 0
    Setting.topic_create_limit_interval = 0
    Setting.topic_create_hour_limit_count = 0
    Setting.sign_up_daily_limit = 0
    Setting.apply_anti_spam_defaults!

    assert_equal 1.day.to_i, Setting.newbie_limit_time
    assert_equal 60, Setting.topic_create_limit_interval
    assert_equal 8, Setting.topic_create_hour_limit_count
    assert_equal 5, Setting.sign_up_daily_limit
  end

  test "rack_attack_limit and period read live settings" do
    Setting.unstub(:rack_attack_limit)
    Setting.rack_attack = {limit: 12, period: 90}
    assert_equal 12, Setting.rack_attack_limit
    assert_equal 90, Setting.rack_attack_period

    Setting.rack_attack = {limit: 10, period: 3.minutes}
    assert_equal 10, Setting.rack_attack_limit
    assert_equal 3.minutes, Setting.rack_attack_period

    Setting.rack_attack = {limit: 0, period: 0}
    assert_equal 0, Setting.rack_attack_limit
    assert_equal 5.minutes, Setting.rack_attack_period
  end
end
