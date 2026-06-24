class AddListingLocationFieldsAndDropLocation < ActiveRecord::Migration[8.0]
  def change
    add_column :rv_listings, :rv_type, :integer, null: false, default: 0
    add_column :rv_listings, :town, :string
    add_column :rv_listings, :state, :string
    add_column :rv_listings, :postcode, :string
    remove_column :rv_listings, :location, :string
  end
end
