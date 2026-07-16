module Api
  module V1
    # Hirer-only trip planning for a confirmed booking (ADR-0013). POST enqueues
    # a background generation and the frontend polls GET for the result.
    class TripPlansController < BaseController
      before_action :set_booking
      before_action :require_hirer

      # Cap paid generations per user (ADR-0010), a separate bucket per AI
      # feature. create only — polling GET must never be throttled.
      RATE_LIMIT_WINDOW = 1.hour

      rate_limit to: 5, within: RATE_LIMIT_WINDOW,
                 by: -> { current_user.id },
                 with: -> { render_rate_limited },
                 only: :create

      # GET /api/v1/bookings/:booking_id/trip_plan
      def show
        plan = TripPlan.find_by(booking_id: @booking.id)
        return render json: { status: "success", data: { status: "none" } } if plan.nil?

        render_plan(plan)
      end

      # POST /api/v1/bookings/:booking_id/trip_plan
      def create
        unless @booking.trip_planning_available?
          return render json: { status: "fail", message: "Trip planning isn't available for this booking." },
                        status: :unprocessable_content
        end

        plan = TripPlan.find_or_initialize_by(booking_id: @booking.id)

        if plan.persisted? && (plan.pending? || plan.processing?)
          return render json: { status: "fail", message: "A trip plan is already being generated." },
                        status: :conflict
        end

        interests = params[:interests].to_s.strip
        hash = input_hash_for(interests)

        if plan.completed? && plan.input_hash == hash
          return render_plan(plan) # unchanged inputs — reuse, no paid call
        end

        plan.update!(status: :pending, interests: interests, input_hash: hash, itinerary: nil, error: nil)
        GenerateTripPlanJob.perform_later(plan.id)

        render_plan(plan, status: :accepted)
      rescue ActiveRecord::RecordNotUnique
        # A concurrent request created the plan first — treat as already generating.
        render json: { status: "fail", message: "A trip plan is already being generated." },
               status: :conflict
      end

      private

      def set_booking
        @booking = Booking.find(params[:id])
      end

      def require_hirer
        return if @booking.hirer_id == current_user.id

        render json: { status: "fail", message: "Forbidden" }, status: :forbidden
      end

      # The plan is a function of the region, the booking dates and the interests;
      # an unchanged hash means a re-run would produce the same inputs (ADR-0013).
      def input_hash_for(interests)
        Digest::SHA256.hexdigest(
          [ @booking.rv_listing.region, @booking.start_date, @booking.end_date, interests ].join("\n")
        )
      end

      def render_plan(plan, status: :ok)
        render json: {
          status: "success",
          data: {
            status:    plan.status,
            interests: plan.interests,
            itinerary: plan.itinerary,
            error:     plan.error
          }
        }, status: status
      end

      def render_rate_limited
        response.set_header("Retry-After", RATE_LIMIT_WINDOW.to_i.to_s)
        render json: { status: "fail", message: "Rate limit exceeded. Please try again later." },
               status: :too_many_requests
      end
    end
  end
end
