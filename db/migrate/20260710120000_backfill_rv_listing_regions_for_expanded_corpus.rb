class BackfillRvListingRegionsForExpandedCorpus < ActiveRecord::Migration[8.0]
  # Re-resolve rv_listings.region after the region manifest gained ten new
  # regions (ADR-0013). Listings whose town now matches a region were left with
  # region: nil by the original backfill, and the before_validation resolver only
  # runs when a row is saved — so existing rows need an explicit re-resolve.
  #
  # Idempotent and derived: update_column skips validations, the region callback,
  # and the embedding refresh, and only writes when the slug actually changes.
  def up
    RvListing.reset_column_information
    RvListing.find_each do |listing|
      slug = Region::Resolver.call(town: listing.town, state: listing.state, postcode: listing.postcode)
      listing.update_column(:region, slug) if listing.region != slug
    end
  end

  def down
    # no-op: region is derived from location and can be recomputed at any time.
  end
end
