# frozen_string_literal: true

require "spec_helper"

describe Notifications::NotificationsController do
  let(:user) { create :user }

  describe "GET /notifications" do
    it "should work" do
      sign_in user
      create :notification_mention, user: user
      get "/notifications"
      assert_equal 200, response.status
    end

    it "should not crash when mention reply was deleted" do
      sign_in user
      create :notification, user: user, notify_type: "mention",
        target_type: "Reply", target_id: -1, second_target: nil
      get "/notifications"
      assert_equal 200, response.status
      assert_includes response.body, I18n.t("notifications.source_deleted")
    end

    it "should not crash when notify type has no partial" do
      sign_in user
      create :notification, user: user, notify_type: "unknown_plugin_type"
      get "/notifications"
      assert_equal 200, response.status
      assert_includes response.body, I18n.t("notifications.source_deleted")
    end
  end
end
