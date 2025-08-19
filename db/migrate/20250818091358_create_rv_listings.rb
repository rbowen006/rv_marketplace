class CreateRvListings < ActiveRecord::Migration[8.0]
  def change
    create_table :rv_listings do |t|
      t.string :title
      t.text :description
      t.string :location
      t.decimal :price_per_day
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
