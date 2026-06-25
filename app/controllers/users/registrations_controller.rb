class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  # Devise's default create calls sign_up → sign_in, which writes to the
  # session. Rails API-only mode disables sessions, so we skip that step.
  def create
    build_resource(sign_up_params)
    resource.save
    clean_up_passwords(resource)
    respond_with(resource)
  end

  private

  def respond_with(resource, _opts = {})
    if resource.persisted?
      render json: { user: resource }, status: :created
    else
      render json: { errors: resource.errors.full_messages }, status: :unprocessable_content
    end
  end
end
