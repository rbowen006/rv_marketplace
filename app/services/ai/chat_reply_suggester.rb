module Ai
  class ChatReplySuggester < BaseAiService
    PROMPT_FEATURE = "chat_reply"
    PROMPT_VERSION = "v1"

    MAX_MESSAGES = 10
    MAX_MESSAGE_LENGTH = 500

    def initialize(chat: nil, user: nil)
      @chat = chat
      @user = user
    end

    def validate_input!
      raise Ai::InputError, "Missing chat" if @chat.nil?
    end

    def build_user_message
      payload = { perspective: "owner", messages: conversation }
      payload[:listing] = listing_facts if @chat.rv_listing
      payload
    end

    def output_schema
      {
        "type"       => "object",
        "required"   => [ "reply" ],
        "properties" => {
          "reply" => { "type" => "string", "minLength" => 1 }
        },
        "additionalProperties" => false
      }
    end

    private

    def listing_facts
      listing = @chat.rv_listing
      {
        title:         listing.title,
        description:   listing.description,
        rv_type:       listing.rv_type,
        town:          listing.town,
        state:         listing.state,
        max_guests:    listing.max_guests,
        pet_friendly:  listing.pet_friendly,
        price_per_day: listing.price_per_day
      }
    end

    def conversation
      recent_messages.map do |message|
        { role: role_for(message), content: message.content.truncate(MAX_MESSAGE_LENGTH, omission: "…") }
      end
    end

    # Most recent MAX_MESSAGES, returned oldest-first. Materialised before reversing
    # so we never call .last/.reverse on a live relation.
    def recent_messages
      @chat.messages.order(created_at: :desc).limit(MAX_MESSAGES).to_a.reverse
    end

    def role_for(message)
      message.user_id == @chat.hirer_id ? "hirer" : "owner"
    end
  end
end
