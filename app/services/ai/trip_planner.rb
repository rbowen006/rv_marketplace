module Ai
  # Generates a grounded, day-by-day itinerary for a confirmed booking (ADR-0013).
  # RAG: embeds a query built from the interests + region + season, retrieves the
  # region's nearest KnowledgeChunks, and asks Claude for structured JSON grounded
  # in them. Runs from GenerateTripPlanJob, not a request.
  class TripPlanner < BaseAiService
    PROMPT_FEATURE = "trip_plan"
    PROMPT_VERSION = "v1"

    # Context management (ADR-0013): plan at most this many days regardless of
    # how long the booking is, bounding retrieval size, output tokens and cost.
    MAX_PLANNED_DAYS = 7
    RETRIEVAL_LIMIT  = 6

    # Output budget, DERIVED from MAX_PLANNED_DAYS so the two can't drift apart
    # (#75: a fixed 2048 was set independently, couldn't hold 7 days, and
    # truncated the last day). We're billed on tokens actually emitted, not on
    # this ceiling, so it's sized generously: a full plan measured ~340 output
    # tokens/day, and 500/day plus a fixed base for the summary/disclaimer/JSON
    # scaffolding leaves comfortable headroom (~4000 for 7 days vs ~2389 needed).
    BASE_OUTPUT_TOKENS     = 512
    TOKENS_PER_PLANNED_DAY = 500
    MAX_TOKENS = BASE_OUTPUT_TOKENS + TOKENS_PER_PLANNED_DAY * MAX_PLANNED_DAYS

    def initialize(booking: nil, interests: nil, user: nil)
      @booking   = booking
      @interests = interests.to_s.strip
      @user      = user
    end

    def validate_input!
      raise Ai::InputError, "Missing booking" if @booking.nil?
    end

    def build_user_message
      {
        destination: destination,
        dates:       date_facts,
        party_size:  listing.max_guests,
        interests:   @interests.presence,
        knowledge:   knowledge
      }.compact
    end

    def output_schema
      {
        "type"                 => "object",
        "required"             => %w[summary disclaimer days],
        "additionalProperties" => false,
        "properties"           => {
          "summary"    => { "type" => "string", "minLength" => 1 },
          "disclaimer" => { "type" => "string", "minLength" => 1 },
          "days"       => {
            "type"  => "array",
            "items" => {
              "type"                 => "object",
              "required"             => %w[date title segments],
              "additionalProperties" => false,
              "properties"           => {
                "date"     => { "type" => "string" },
                "title"    => { "type" => "string" },
                "segments" => {
                  "type"  => "array",
                  "items" => {
                    "type"                 => "object",
                    "required"             => %w[part_of_day activity],
                    "additionalProperties" => false,
                    "properties"           => {
                      "part_of_day" => { "type" => "string" },
                      "activity"    => { "type" => "string" },
                      "detail"      => { "type" => "string" }
                    }
                  }
                }
              }
            }
          }
        }
      }
    end

    private

    def listing
      @booking.rv_listing
    end

    def region
      @region ||= Region.find(listing.region)
    end

    def destination
      { region: region&.name, town: listing.town, state: listing.state }
    end

    def nights
      (@booking.end_date - @booking.start_date).to_i
    end

    def date_facts
      {
        start_date:        @booking.start_date.iso8601,
        end_date:          @booking.end_date.iso8601,
        nights:            nights,
        season:            season,
        plan_dates:        planned_dates,
        additional_nights: [ nights - MAX_PLANNED_DAYS, 0 ].max
      }
    end

    # The real calendar dates to plan, capped at MAX_PLANNED_DAYS.
    def planned_dates
      [ nights, MAX_PLANNED_DAYS ].min.times.map { |offset| (@booking.start_date + offset).iso8601 }
    end

    def knowledge
      KnowledgeChunk
        .retrieve(region: listing.region, query_embedding: query_embedding, limit: RETRIEVAL_LIMIT)
        .map { |chunk| { heading: chunk.heading, content: chunk.content } }
    end

    def query_embedding
      @query_embedding ||= Ai::Embedder.call(query_text, feature: PROMPT_FEATURE, user: @user)
    end

    def query_text
      [ @interests.presence, region&.name, season, "#{listing.max_guests} people" ].compact.join(", ")
    end

    # Southern-hemisphere season from the start month (ADR-0013).
    def season
      case @booking.start_date.month
      when 12, 1, 2 then "summer"
      when 3, 4, 5  then "autumn"
      when 6, 7, 8  then "winter"
      else               "spring"
      end
    end
  end
end
