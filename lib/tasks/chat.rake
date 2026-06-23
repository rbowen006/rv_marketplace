namespace :chat do
  desc 'Re-sync denormalized inbox fields (last_message_at, last_message_content) on chats from actual messages. Safe to run at any time; skips chats with no messages.'
  task resync_inbox_fields: :environment do
    Chat.resync_inbox_fields!
    puts 'Done.'
  end
end
