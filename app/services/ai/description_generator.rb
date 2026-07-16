module Ai
  class DescriptionGenerator < BaseAiService
    PROMPT_FEATURE = "description_generator"
    PROMPT_VERSION = "v1"

    # Kept in sync by hand with GENERATE_REQUIRED_FIELDS
    # (frontend/src/components/ListingForm.jsx) — no shared schema between
    # backend and frontend, so a mismatch here won't fail loudly.
    REQUIRED_FIELDS = %i[rv_type town state max_guests].freeze

    def initialize(rv_type: nil, town: nil, state: nil, max_guests: nil, pet_friendly: false, price_per_day: nil, user: nil)
      @rv_type      = rv_type
      @town         = town
      @state        = state
      @max_guests   = max_guests
      @pet_friendly = pet_friendly
      @price_per_day = price_per_day
      @user         = user
    end

    def validate_input!
      missing = REQUIRED_FIELDS.select { |f| instance_variable_get(:"@#{f}").blank? }
      raise Ai::InputError, "Missing required fields: #{missing.join(', ')}" if missing.any?
    end

    def build_user_message
      {
        rv_type:       @rv_type,
        town:          @town,
        state:         @state,
        max_guests:    @max_guests,
        pet_friendly:  @pet_friendly,
        price_per_day: @price_per_day
      }
    end

    def output_schema
      {
        "type"       => "object",
        "required"   => [ "description" ],
        "properties" => {
          "description" => { "type" => "string", "minLength" => 1 }
        },
        "additionalProperties" => false
      }
    end
  end
end
