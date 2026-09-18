# frozen_string_literal: true

namespace :products do
  desc "Backfill Product records from the product node topics"
  task backfill: :environment do
    created = Product.backfill_from_node!
    puts "Done. created=#{created}"
  end

  desc "Remove products whose topics were deleted"
  task prune_orphans: :environment do
    count = 0
    Product.orphaned.find_each do |product|
      puts "destroy ##{product.id} #{product.name}"
      product.destroy
      count += 1
    end
    puts "Done. destroyed=#{count}"
  end
end
