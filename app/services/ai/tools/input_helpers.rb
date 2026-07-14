module Ai
  module Tools
    # Shared input parsing for the concierge data tools (ADR-0014): resolve a
    # listing by id and parse a date range, raising Ai::InputError on anything
    # malformed so the agent gets an is_error tool_result and recovers rather
    # than the job crashing.
    module InputHelpers
      private

      def resolve_listing!(id)
        RvListing.find_by(id: id) || raise(Ai::InputError, "No listing with id #{id}")
      end

      def parse_range!(start_value, end_value)
        start_date = parse_date!(start_value)
        end_date   = parse_date!(end_value)
        raise Ai::InputError, "end_date must be after start_date" unless end_date > start_date

        [start_date, end_date]
      end

      def parse_date!(value)
        Date.iso8601(value.to_s)
      rescue ArgumentError
        raise Ai::InputError, "Invalid date: #{value.inspect}"
      end
    end
  end
end
