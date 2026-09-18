# frozen_string_literal: true

namespace :products do
  desc "Backfill Product records from the product node topics"
  task backfill: :environment do
    created = Product.backfill_from_node!
    puts "Done. created=#{created}"
  end
end
