module Api
  module V1
    class DescriptionGeneratorController < BaseController
      # Cap paid Claude calls per user (see ADR-0010). Runs after authenticate_user!,
      # so current_user is available. Backed by Rails.cache (Solid Cache in prod).
      RATE_LIMIT_WINDOW = 1.hour

      rate_limit to: 10, within: RATE_LIMIT_WINDOW,
                 by: -> { current_user.id },
                 with: -> { render_rate_limited }

      def create
        data = Ai::DescriptionGenerator.call(**generator_params, user: current_user)
        render json: { status: "success", data: data }, status: :ok
      rescue Ai::InputError => e
        render json: { status: "fail", message: e.message }, status: :bad_request
      rescue Ai::ApiError => e
        render json: { status: "error", message: e.message }, status: :service_unavailable
      rescue Ai::OutputError => e
        render json: { status: "error", message: e.message }, status: :internal_server_error
      end

      private

      def render_rate_limited
        response.set_header("Retry-After", RATE_LIMIT_WINDOW.to_i.to_s)
        render json: { status: "fail", message: "Rate limit exceeded. Please try again later." },
               status: :too_many_requests
      end

      def generator_params
        p = params.permit(:rv_type, :town, :state, :max_guests, :pet_friendly, :price_per_day)
                  .to_h
                  .symbolize_keys
        p[:pet_friendly]  = ActiveModel::Type::Boolean.new.cast(p[:pet_friendly]) if p.key?(:pet_friendly)
        p[:max_guests]    = p[:max_guests].to_i    if p.key?(:max_guests)
        p[:price_per_day] = p[:price_per_day].to_f if p.key?(:price_per_day)
        p
      end
    end
  end
end
