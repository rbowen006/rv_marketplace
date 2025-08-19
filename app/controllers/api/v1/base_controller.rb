module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate_user!

      private

      def render_unprocessable(record)
      render json: { errors: record.errors.full_messages }, status: :unprocessable_content
      end
    end
  end
end
