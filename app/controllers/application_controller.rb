class ApplicationController < ActionController::API
	include ActionController::MimeResponds

	respond_to :json

	# Devise helper for API-only apps
	before_action :configure_permitted_parameters, if: :devise_controller?

	protected

	def configure_permitted_parameters
		devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
	end
end
