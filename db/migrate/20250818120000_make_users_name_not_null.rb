class MakeUsersNameNotNull < ActiveRecord::Migration[8.0]
  def up
    # Ensure no NULL names exist before adding NOT NULL constraint
    execute "UPDATE users SET name = 'Unnamed User' WHERE name IS NULL OR name = ''"
    change_column_null :users, :name, false, 'Unnamed User'
  end

  def down
    change_column_null :users, :name, true
  end
end
