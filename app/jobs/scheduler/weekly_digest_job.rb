# frozen_string_literal: true

module Scheduler
  class WeeklyDigestJob < ApplicationJob
    queue_as :mailer

    def perform(week_id = nil)
      digest = WeeklyDigest.find(week_id)
      User.digest_recipients.find_in_batches(batch_size: 100) do |users|
        users.each do |user|
          UserMailer.weekly_digest(user.id, digest.to_param).deliver_later
        end
      end
    end
  end
end
