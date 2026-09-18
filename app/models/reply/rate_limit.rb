# frozen_string_literal: true

class Reply
  module RateLimit
    extend ActiveSupport::Concern

    included do
      before_validation :_rate_limit_create, on: :create, unless: :system_event?
      after_commit :_log_rate_limit_create, on: :create, unless: :system_event?
    end

    private

    def _rate_limit_key
      @rate_limit_key ||= "users:#{user_id}:reply-create"
    end

    def _rate_limit_hour_key
      @rate_limit_hour_key ||= "users:#{user_id}:reply-create-by-hour"
    end

    def _rate_limit_create
      if Rails.cache.read(_rate_limit_key)
        errors.add(:base, I18n.t("replies.create_too_frequently"))
      end

      count_limit = _reply_create_hour_limit
      if count_limit > 0
        count = Rails.cache.read(_rate_limit_hour_key) || 0
        if count >= count_limit
          errors.add(:base, I18n.t("replies.create_limit", count: count_limit))
        end
      end
    end

    def _log_rate_limit_create
      limit_interval = _reply_create_interval
      if limit_interval > 0
        Rails.cache.write(_rate_limit_key, 1, expires_in: limit_interval)
      end

      count = Rails.cache.read(_rate_limit_hour_key) || 0
      Rails.cache.write(_rate_limit_hour_key, count + 1, expires_in: 1.hour)
    end

    def _reply_create_interval
      interval = Setting.reply_create_limit_interval.to_i
      interval *= 2 if _newbie_rate_limited?
      interval
    end

    def _reply_create_hour_limit
      limit = Setting.reply_create_hour_limit_count.to_i
      return 0 if limit <= 0
      _newbie_rate_limited? ? [limit / 2, 1].max : limit
    end

    def _newbie_rate_limited?
      user&.newbie?
    end
  end
end
