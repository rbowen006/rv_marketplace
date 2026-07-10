class BackfillRvListingRegions < ActiveRecord::Migration[8.0]
  # Populate rv_listings.region for rows created before the column existed
  # (ADR-0013). Derived data, so update_column skips validations, the region
  # callback, and the embedding refresh.
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
