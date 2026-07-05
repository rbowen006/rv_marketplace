namespace :embeddings do
  desc "Enqueue semantic-search embedding generation for every listing (ADR-0011 backfill)"
  task backfill: :environment do
    count = 0
    RvListing.find_each do |listing|
      GenerateListingEmbeddingJob.perform_later(listing.id)
      count += 1
    end
    puts "Enqueued GenerateListingEmbeddingJob for #{count} listing(s)."
  end
end
