# frozen_string_literal: true

class CreateProducts < ActiveRecord::Migration[6.1]
  def change
    create_table :products do |t|
      t.integer :user_id, null: false
      t.integer :topic_id
      t.string :name, null: false, limit: 40
      t.string :tagline, limit: 80
      t.string :url
      t.string :cover
      t.integer :status, null: false, default: 1
      t.datetime :launched_at
      t.timestamps null: false
    end

    add_index :products, :user_id
    add_index :products, :launched_at
    add_index :products, :topic_id, unique: true
  end
end
