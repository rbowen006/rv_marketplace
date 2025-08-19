class AddBookingsExclusionConstraint < ActiveRecord::Migration[8.0]
  def up
    return unless ActiveRecord::Base.connection.adapter_name.downcase.starts_with?('post')

    execute <<-SQL.squish
      ALTER TABLE bookings
      ADD CONSTRAINT bookings_no_overlap EXCLUDE USING GIST (
        rv_listing_id WITH =,
        tsrange(start_date::timestamp, end_date::timestamp, '[]') WITH &&
      ) WHERE (status <> 'rejected');
    SQL
  end

  def down
    return unless ActiveRecord::Base.connection.adapter_name.downcase.starts_with?('post')

    execute <<-SQL.squish
      ALTER TABLE bookings
      DROP CONSTRAINT IF EXISTS bookings_no_overlap;
    SQL
  end
end
