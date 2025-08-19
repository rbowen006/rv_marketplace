require 'swagger_helper'

RSpec.describe 'API V1', type: :request do
  # helper to build a JWT for a user using Warden::JWTAuth
  def jwt_for(user)
    Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
  end

  path '/api/v1/listings' do
    get 'List listings' do
      tags 'Listings'
      produces 'application/json'

      response '200', 'listings found' do
        run_test!
      end
    end

    post 'Create listing' do
      tags 'Listings'
      consumes 'application/json'
      parameter name: :listing, in: :body, schema: {
        type: :object,
        properties: {
          listing: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string },
              location: { type: :string },
              price_per_day: { type: :number }
            },
            required: ['title','description','location','price_per_day']
          }
        }
      }

      parameter name: 'Authorization', in: :header, type: :string

      response '201', 'listing created' do
        let(:user) { create(:user, name: 'Rswag') }
        let(:Authorization) { "Bearer #{jwt_for(user)}" }
        let(:listing) { { listing: { title: 'X', description: 'D', location: 'L', price_per_day: 100 } } }
        run_test!
      end

      response '401', 'unauthorized' do
        # No Authorization header provided for this example
        let(:Authorization) { nil }
        # rswag requires declared body params to have corresponding lets, provide empty
        let(:listing) { {} }
        run_test!
      end
    end
  end

  path '/api/v1/listings/{id}' do
    get 'Retrieves a listing' do
      tags 'Listings'
      produces 'application/json'
      parameter name: :id, in: :path, type: :integer

      response '200', 'listing found' do
        let(:id) { RvListing.create(title: 't', description: 'd', location: 'l', price_per_day: 10, user_id: User.first&.id || User.create!(email: 'lister@example.com', password: 'password', name: 'Lister').id).id }
        run_test!
      end

      response '404', 'not found' do
        let(:id) { 'invalid' }
        run_test!
      end
    end

    put 'Update listing' do
      tags 'Listings'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :id, in: :path, type: :integer
      parameter name: :listing, in: :body, schema: {
        type: :object,
        properties: {
          listing: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string },
              location: { type: :string },
              price_per_day: { type: :number }
            }
          }
        }
      }
      parameter name: 'Authorization', in: :header, type: :string

      response '200', 'listing updated' do
        let(:owner) { create(:user) }
        let(:listing_record) { create(:rv_listing, user: owner) }
        let(:id) { listing_record.id }
        let(:Authorization) { "Bearer #{jwt_for(owner)}" }
        let(:listing) { { listing: { title: 'Updated Title' } } }
        run_test!
      end

      response '403', 'forbidden (non-owner)' do
        let(:owner) { create(:user) }
        let(:other) { create(:user) }
        let(:listing_record) { create(:rv_listing, user: owner) }
        let(:id) { listing_record.id }
        let(:Authorization) { "Bearer #{jwt_for(other)}" }
        let(:listing) { { listing: { title: 'Hack' } } }
        run_test!
      end

      response '401', 'unauthorized (no token)' do
        let(:listing_record) { create(:rv_listing, user: create(:user)) }
        let(:id) { listing_record.id }
        let(:Authorization) { nil }
        let(:listing) { { listing: { title: 'New' } } }
        run_test!
      end
    end

    delete 'Delete listing' do
      tags 'Listings'
      parameter name: :id, in: :path, type: :integer
      parameter name: 'Authorization', in: :header, type: :string

      response '204', 'listing deleted' do
        let(:owner) { create(:user) }
        let(:listing_record) { create(:rv_listing, user: owner) }
        let(:id) { listing_record.id }
        let(:Authorization) { "Bearer #{jwt_for(owner)}" }
        run_test!
      end

      response '403', 'forbidden (non-owner)' do
        let(:owner) { create(:user) }
        let(:other) { create(:user) }
        let(:listing_record) { create(:rv_listing, user: owner) }
        let(:id) { listing_record.id }
        let(:Authorization) { "Bearer #{jwt_for(other)}" }
        run_test!
      end

      response '401', 'unauthorized (no token)' do
        let(:listing_record) { create(:rv_listing, user: create(:user)) }
        let(:id) { listing_record.id }
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  path '/api/v1/listings/{listing_id}/bookings' do
    post 'Create booking' do
      tags 'Bookings'
      consumes 'application/json'
      parameter name: :listing_id, in: :path, type: :integer
      parameter name: :booking, in: :body, schema: {
        type: :object,
        properties: {
          booking: {
            type: :object,
            properties: {
              start_date: { type: :string, format: :date },
              end_date: { type: :string, format: :date }
            },
            required: ['start_date','end_date']
          }
        }
      }

      parameter name: 'Authorization', in: :header, type: :string

      response '201', 'booking created' do
        let(:owner) { create(:user) }
        let(:listing) { create(:rv_listing, user: owner, title: 'x') }
        let(:hirer) { create(:user) }
        let(:listing_id) { listing.id }
        let(:Authorization) { "Bearer #{jwt_for(hirer)}" }
        let(:booking) { { booking: { start_date: Date.today + 1, end_date: Date.today + 2 } } }
        run_test!
      end

      response '403', 'forbidden' do
        # Owner attempting to book their own listing should receive 403
        let(:owner) { create(:user) }
        let(:listing) { create(:rv_listing, user: owner, title: 'owned') }
        let(:listing_id) { listing.id }
        let(:Authorization) { "Bearer #{jwt_for(owner)}" }
        # rswag expects the body param to be defined even if not used
        let(:booking) { {} }
        run_test!
      end
    end
  end

  path '/api/v1/bookings/{id}/confirm' do
    patch 'Confirm booking' do
      tags 'Bookings'
      parameter name: :id, in: :path, type: :integer
      parameter name: 'Authorization', in: :header, type: :string

      response '200', 'booking confirmed' do
        let(:owner) { create(:user) }
        let(:hirer) { create(:user) }
        let(:listing) { create(:rv_listing, user: owner, title: 'y', price_per_day: 20) }
        let(:booking) { create(:booking, rv_listing: listing, user: hirer, start_date: Date.today + 2, end_date: Date.today + 3, status: 'pending') }
        let(:id) { booking.id }
        let(:Authorization) { "Bearer #{jwt_for(owner)}" }
        run_test!
      end

      response '403', 'forbidden (non-owner)' do
        let(:owner) { create(:user) }
        let(:hirer) { create(:user) }
        let(:listing) { create(:rv_listing, user: owner) }
        let(:booking) { create(:booking, rv_listing: listing, user: hirer, start_date: Date.today + 1, end_date: Date.today + 2, status: 'pending') }
        let(:id) { booking.id }
        let(:Authorization) { "Bearer #{jwt_for(hirer)}" }
        run_test!
      end

      response '401', 'unauthorized (no token)' do
        let(:owner) { create(:user) }
        let(:hirer) { create(:user) }
        let(:listing) { create(:rv_listing, user: owner) }
        let(:booking) { create(:booking, rv_listing: listing, user: hirer, start_date: Date.today + 1, end_date: Date.today + 2, status: 'pending') }
        let(:id) { booking.id }
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  path '/api/v1/listings/{listing_id}/messages' do
    post 'Create message' do
      tags 'Messages'
      consumes 'application/json'
      parameter name: :listing_id, in: :path, type: :integer
      parameter name: :message, in: :body, schema: {
        type: :object,
        properties: {
          message: {
            type: :object,
            properties: {
              content: { type: :string }
            },
            required: ['content']
          }
        }
      }

      parameter name: 'Authorization', in: :header, type: :string

      response '201', 'message created' do
        let(:owner) { create(:user) }
        let(:listing) { create(:rv_listing, user: owner, title: 'x') }
        let(:hirer) { create(:user) }
        let(:listing_id) { listing.id }
        let(:Authorization) { "Bearer #{jwt_for(hirer)}" }
        let(:message) { { message: { content: 'hi' } } }
        run_test!
      end
    end

    get 'List messages' do
      tags 'Messages'
      produces 'application/json'
      parameter name: :listing_id, in: :path, type: :integer

      response '200', 'messages listed' do
        let(:owner) { create(:user) }
        let(:listing) { create(:rv_listing, user: owner, title: 'x') }
        let(:listing_id) { listing.id }
        parameter name: 'Authorization', in: :header, type: :string
        let(:Authorization) { "Bearer #{jwt_for(owner)}" }
        run_test!
      end
    end
  end
end
