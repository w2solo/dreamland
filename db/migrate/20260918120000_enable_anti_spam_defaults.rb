# frozen_string_literal: true

class EnableAntiSpamDefaults < ActiveRecord::Migration[6.1]
  def up
    Setting.apply_anti_spam_defaults!
  end

  def down
    # Recommended values are safe to keep; do not revert site config on rollback.
  end
end
