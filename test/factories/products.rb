# frozen_string_literal: true

FactoryBot.define do
  factory :product do
    association :user
    sequence(:name) { |n| "Product #{n}" }
    tagline { "A one-line pitch" }
    sequence(:url) { |n| "https://example.com/p#{n}" }
    status { :shipped }
    launched_at { Time.current }
    cover { Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/cover.png"), "image/png") }
    topic { association :topic, user: user, title: name }
  end
end
