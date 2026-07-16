class AddInboxFieldsToChats < ActiveRecord::Migration[8.0]
  def change
    add_column :chats, :last_message_at, :datetime
    add_column :chats, :last_message_content, :text
    add_column :chats, :hirer_last_read_at, :datetime
    add_column :chats, :owner_last_read_at, :datetime

    add_index :chats, [ :hirer_id, :last_message_at ]
    add_index :chats, [ :owner_id, :last_message_at ]
  end
end
