# frozen_string_literal: true

class AddCreateProductGradeRule < ActiveRecord::Migration[6.1]
  def up
    unless Grade::Rule.exists?(action: "create_product")
      Grade::Rule.create!(action: "create_product", message: "发布作品", score: 15, change_type: :increase)
    end
    Setting.apply_anti_spam_defaults!
  end

  def down
    Grade::Rule.where(action: "create_product").delete_all
  end
end
