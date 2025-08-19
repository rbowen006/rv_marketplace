class EnforceStatusNotNullOnBookings < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE bookings SET status='pending' WHERE status IS NULL"
    change_column_default :bookings, :status, 'pending'
    change_column_null :bookings, :status, false
  end

  def down
    change_column_null :bookings, :status, true
    change_column_default :bookings, :status, nil
  end
end
