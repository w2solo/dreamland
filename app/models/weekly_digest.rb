# frozen_string_literal: true

class WeeklyDigest
  ID_REGEXP = /\A(\d{4})-w(\d{1,2})\z/i

  attr_reader :beginning, :ending

  def self.current
    new(Time.zone.today)
  end

  def self.find(week_id = nil)
    return current if week_id.blank?

    year, week = week_id.to_s.match(ID_REGEXP)&.captures
    raise ActiveRecord::RecordNotFound if year.blank?

    new(Date.commercial(year.to_i, week.to_i))
  rescue ArgumentError
    raise ActiveRecord::RecordNotFound
  end

  def initialize(date)
    date = date.to_date
    @beginning = date.beginning_of_week
    @ending = date.end_of_week
  end

  def to_param
    format("%<year>04d-w%<week>02d", year: beginning.cwyear, week: beginning.cweek)
  end

  def products
    @products ||= Product.for_week(beginning, ending).includes(:user, :topic)
  end

  def excellent_topics
    @excellent_topics ||= Topic.excellent.without_ban
      .where(created_at: beginning.beginning_of_day..ending.end_of_day)
      .includes(:user, :node)
      .recent
  end

  def title
    I18n.t("weeklies.title", year: beginning.cwyear, week: beginning.cweek)
  end
end
