class Users::SessionsController < Devise::SessionsController
  respond_to :json

  private

  def respond_with(resource, _opts = {})
  render json: { user: resource }, status: :ok
  end

  # Ignores non_navigational_status intentionally: Devise passes :unauthorized
  # when its session-based all_signed_out? check trips, but that check is
  # unreliable for this app's stateless JWT auth (it's true on every request,
  # including a valid first-time sign-out) — honoring it would report 401 on
  # legitimate sign-outs that actually succeeded.
  def respond_to_on_destroy(non_navigational_status: :no_content)
  head :no_content
  end
end
