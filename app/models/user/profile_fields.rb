# frozen_string_literal: true

class User
  module ProfileFields
    extend ActiveSupport::Concern

    included do
      delegate :contacts, to: :profile, allow_nil: true
      delegate :theme, to: :profile, allow_nil: true
      delegate :weekly_digest, to: :profile, allow_nil: true

      before_save :store_location
    end

    class_methods do
      def find_by_weekly_digest_token(token)
        user_id = Rails.application.message_verifier(:weekly_digest).verify(token)
        find_by(id: user_id)
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        nil
      end
    end

    def profile_field(field)
      return nil if contacts.nil?
      contacts[field.to_s]
    end

    def full_profile_field(field)
      v = profile_field(field)
      prefix = Profile.contact_field_prefix(field)
      return v if prefix.blank?
      [prefix, v].join("")
    end

    def update_theme(value)
      create_profile if profile.blank?
      profile.update(theme: value)
    end

    def weekly_digest?
      weekly_digest.to_s != "false"
    end

    def update_weekly_digest(value)
      create_profile if profile.blank?
      enabled = ActiveModel::Type::Boolean.new.cast(value)
      profile.update(weekly_digest: enabled ? "true" : "false")
    end

    def weekly_digest_token
      Rails.application.message_verifier(:weekly_digest).generate(id)
    end

    def update_profile_fields(field_values)
      val = contacts || {}
      field_values.each do |key, value|
        next unless Profile.has_field?(key)
        val[key.to_s] = value
      end

      create_profile if profile.blank?
      profile.update(contacts: val)
    end

    private

    # Store user location into Location
    def store_location
      return unless location_changed?

      if location.blank?
        self.location_id = nil
        return
      end

      old_location = Location.location_find_by_name(location_was)
      old_location&.decrement!(:users_count)

      location = Location.location_find_or_create_by_name(self.location)
      if !location.new_record?
        location.increment!(:users_count)
        self.location_id = location.id
      end
    end
  end
end
