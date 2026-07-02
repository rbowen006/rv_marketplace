require 'rails_helper'

RSpec.describe 'DELETE /users/sign_out', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_header_for(user) }

  it 'signs out without crashing' do
    delete '/users/sign_out', headers: headers

    expect(response).to have_http_status(:no_content)
  end
end
