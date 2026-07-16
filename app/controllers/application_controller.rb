class ApplicationController < ActionController::API
  include ActionController::MimeResponds

  respond_to :json

  # Devise helper for API-only apps
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from ActionDispatch::Http::Parameters::ParseError do |e|
    render json: { status: "fail", message: "Malformed request body" }, status: :bad_request
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
  end
end
