require 'rails_helper'

RSpec.describe 'Listing Images API', type: :request do
  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }
  let!(:listing) { create(:rv_listing, owner: owner) }

  let(:image_file) { fixture_file_upload('test.png', 'image/png') }

  def auth_bearer(user)
    { 'Authorization' => "Bearer #{auth_token_for(user)}" }
  end

  describe 'POST /api/v1/listings/:listing_id/images' do
    it 'requires auth' do
      post "/api/v1/listings/#{listing.id}/images", params: { images: [ image_file ] }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'forbids non-owner' do
      post "/api/v1/listings/#{listing.id}/images",
           params: { images: [ image_file ] },
           headers: auth_bearer(other_user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'attaches images and returns updated listing' do
      post "/api/v1/listings/#{listing.id}/images",
           params: { images: [ image_file ] },
           headers: auth_bearer(owner)
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['images'].length).to eq(2)
      expect(body['images'].first).to include('id', 'url')
    end
  end

  describe 'DELETE /api/v1/listings/:listing_id/images/:id' do
    let!(:attachment_id) do
      listing.images.attach(image_file)
      listing.images.attachments.last.id
    end

    it 'requires auth' do
      delete "/api/v1/listings/#{listing.id}/images/#{attachment_id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'forbids non-owner' do
      delete "/api/v1/listings/#{listing.id}/images/#{attachment_id}",
             headers: auth_bearer(other_user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'removes the image and returns 204' do
      delete "/api/v1/listings/#{listing.id}/images/#{attachment_id}",
             headers: auth_bearer(owner)
      expect(response).to have_http_status(:no_content)
      expect(listing.images.attachments.exists?(attachment_id)).to be false
    end
  end
end
