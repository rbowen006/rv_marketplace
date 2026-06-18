class RenameUserIdToOwnerIdOnRvListings < ActiveRecord::Migration[8.0]
  def change
    rename_column :rv_listings, :user_id, :owner_id
  end
end
