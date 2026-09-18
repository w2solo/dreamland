# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def welcome(user_id)
    @user = User.find_by_id(user_id)
    return false if @user.blank?
    mail(to: @user.email, subject: t("mail.welcome_subject", app_name: Setting.app_name).to_s)
  end

  def weekly_digest(user_id, week_id)
    @user = User.find_by_id(user_id)
    return false if @user.blank?
    @digest = WeeklyDigest.find(week_id)
    @unsubscribe_url = unsubscribe_weekly_digest_url(token: @user.weekly_digest_token)
    mail(to: @user.email, subject: t("mail.weekly_digest_subject", title: @digest.title, app_name: Setting.app_name).to_s)
  end
end
