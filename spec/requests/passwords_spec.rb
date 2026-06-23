require 'rails_helper'

RSpec.describe 'Password Reset', type: :request do
  let(:user) { create(:user) }

  before { ActionMailer::Base.deliveries.clear }

  describe 'POST /users/password' do
    it 'returns 200 and sends no email when the email is not registered' do
      post '/users/password',
           params: { user: { email: 'nobody@example.com' } }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:ok)
      expect(ActionMailer::Base.deliveries.count).to eq(0)
    end

    it 'returns 200 and sends a reset email when the email is registered' do
      post '/users/password',
           params: { user: { email: user.email } }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:ok)
      expect(ActionMailer::Base.deliveries.count).to eq(1)
      expect(ActionMailer::Base.deliveries.last.to).to include(user.email)
    end
  end

  describe 'PUT /users/password' do
    it 'returns 422 when the token is invalid or expired' do
      put '/users/password',
          params: { user: { reset_password_token: 'bogus', password: 'newpassword1', password_confirmation: 'newpassword1' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['errors']).to be_present
    end

    it 'returns 422 when the passwords do not match' do
      raw_token = user.send_reset_password_instructions

      put '/users/password',
          params: { user: { reset_password_token: raw_token, password: 'newpassword1', password_confirmation: 'different' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['errors']).to be_present
    end

    it 'returns 200 and updates the password when the token is valid' do
      raw_token = user.send_reset_password_instructions

      put '/users/password',
          params: { user: { reset_password_token: raw_token, password: 'newpassword1', password_confirmation: 'newpassword1' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:ok)
      expect(user.reload.valid_password?('newpassword1')).to be true
    end
  end
end
