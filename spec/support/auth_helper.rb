module AuthHelper
  def auth_token_for(user)
    post '/users/sign_in', params: { user: { email: user.email, password: user.password || 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
    response.headers['Authorization']&.split(' ')&.last
  end

  def auth_header_for(user)
    token = auth_token_for(user)
    { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end
