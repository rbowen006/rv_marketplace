module Api
  module V1
    class BookingsController < BaseController
      before_action :set_booking, only: [:confirm, :reject]

      # GET /api/v1/bookings
      def index
        # Bookings where user is hirer OR owner of the listing
        @bookings = Booking.joins(:rv_listing)
                           .where('bookings.user_id = ? OR rv_listings.user_id = ?', current_user.id, current_user.id)
        render json: @bookings
      end

      # POST /api/v1/listings/:listing_id/bookings
      def create
        @listing = RvListing.find(params[:listing_id])
        if @listing.user_id == current_user.id
          return render json: { error: 'Owners cannot book their own listing' }, status: :forbidden
        end

        booking = nil
        Booking.transaction do
          # lock relevant bookings rows for this listing to avoid race conditions
          @listing.bookings.lock(true).to_a

          booking = @listing.bookings.build(booking_params)
          booking.user = current_user
          booking.status = 'pending'

          unless booking.save
            return render json: { errors: booking.errors.full_messages }, status: :unprocessable_content
          end
        end

        render json: booking, status: :created
      end

      # PATCH /api/v1/bookings/:id/confirm
      def confirm
        unless @booking.rv_listing.user_id == current_user.id
          return render json: { error: 'Only listing owner can confirm' }, status: :forbidden
        end

        @booking.update(status: 'confirmed')
        render json: @booking
      end

      # PATCH /api/v1/bookings/:id/reject
      def reject
        unless @booking.rv_listing.user_id == current_user.id
          return render json: { error: 'Only listing owner can reject' }, status: :forbidden
        end

        @booking.update(status: 'rejected')
        render json: @booking
      end

      private

      def set_booking
        @booking = Booking.find(params[:id])
      end

      def booking_params
        params.require(:booking).permit(:start_date, :end_date)
      end
    end
  end
end
