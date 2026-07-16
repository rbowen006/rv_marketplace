class Users::PasswordsController < Devise::PasswordsController
  respond_to :json

  def create
    User.send_reset_password_instructions(email: params.dig(:user, :email))
    render json: { message: "If that email is registered you will receive a reset link shortly." }, status: :ok
  end

  def update
    user = User.reset_password_by_token(reset_password_params)
    if user.errors.empty?
      render json: { message: "Password updated successfully." }, status: :ok
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def reset_password_params
    params.require(:user).permit(:reset_password_token, :password, :password_confirmation)
  end
end
