class RenameUserIdToHirerIdOnBookings < ActiveRecord::Migration[8.0]
  def change
    rename_column :bookings, :user_id, :hirer_id
  end
end
