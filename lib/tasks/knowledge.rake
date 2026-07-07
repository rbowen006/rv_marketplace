namespace :knowledge do
  desc "Embed the trip-planning knowledge corpus into knowledge_chunks (ADR-0013). Idempotent — safe to re-run at deploy."
  task embed: :environment do
    Region.all.each do |region|
      body = region.doc_body
      next if body.blank?

      count = Knowledge::Ingestor.call(region: region.slug, markdown: body)
      puts "  #{region.slug}: #{count} chunks"
    end
  end
end
