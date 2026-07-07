class AddRegionToRvListings < ActiveRecord::Migration[8.0]
  def change
    add_column :rv_listings, :region, :string
  end
end
