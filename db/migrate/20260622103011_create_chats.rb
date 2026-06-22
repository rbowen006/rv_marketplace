class CreateChats < ActiveRecord::Migration[8.0]
  def change
    create_table :chats do |t|
      t.references :hirer, null: false, foreign_key: { to_table: :users }
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.references :rv_listing, null: true, foreign_key: true
      t.references :booking, null: true, foreign_key: true

      t.timestamps
    end
  end
end
