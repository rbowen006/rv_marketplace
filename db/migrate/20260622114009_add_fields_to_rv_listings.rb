class AddFieldsToRvListings < ActiveRecord::Migration[8.0]
  def change
    add_column :rv_listings, :max_guests, :integer, null: false, default: 1
    add_column :rv_listings, :pet_friendly, :boolean, null: false, default: false
    add_column :rv_listings, :latitude, :float
    add_column :rv_listings, :longitude, :float
  end
end
