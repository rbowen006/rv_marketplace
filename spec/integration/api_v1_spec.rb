require 'swagger_helper'

RSpec.describe 'API V1', type: :request do
  # helper to build a JWT for a user using Warden::JWTAuth
  def jwt_for(user)
    Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
  end

  before { host! 'localhost' }

  LISTING_SCHEMA = {
    type: :object,
    properties: {
      listing: {
        type: :object,
        properties: {
          title: { type: :string },
          description: { type: :string },
          rv_type: { type: :string },
          town: { type: :string },
          state: { type: :string },
          postcode: { type: :string },
          price_per_day: { type: :number },
          max_guests: { type: :integer },
          pet_friendly: { type: :boolean },
          latitude: { type: :number, nullable: true },
          longitude: { type: :number, nullable: true }
        },
        required: [ 'title', 'description', 'rv_type', 'town', 'state', 'postcode', 'price_per_day', 'max_guests' ]
      }
    }
  }.freeze

  MESSAGE_SCHEMA = {
    type: :object,
    properties: {
      message: {
        type: :object,
        properties: { content: { type: :string } },
        required: [ 'content' ]
      }
    }
  }.freeze

  path '/up' do
    get 'Health check' do
      tags 'Health'
      response '200', 'application is healthy' do
        run_test!
      end
    end
  end

  path '/users' do
    post 'Register user' do
      tags 'Users'
      consumes 'application/json'
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, format: :email },
              password: { type: :string },
              password_confirmation: { type: :string },
              name: { type: :string }
            },
            required: [ 'email', 'password', 'password_confirmation', 'name' ]
          }
        }
      }

      response '201', 'user registered' do
        run_test! skip: 'documented route; Devise writes to session in this API-only test harness'
      end
    end

    patch 'Update user registration' do
      tags 'Users'
      consumes 'application/json'
      parameter name: 'Authorization', in: :header, type: :string
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, format: :email },
              name: { type: :string },
              password: { type: :string },
              password_confirmation: { type: :string },
              current_password: { type: :string }
            }
          }
        }
      }

      response '200', 'user updated' do
        run_test! skip: 'documented route; Devise writes to session in this API-only test harness'
      end
    end

    put 'Update user registration' do
      tags 'Users'
      consumes 'application/json'
      parameter name: 'Authorization', in: :header, type: :string
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, format: :email },
              name: { type: :string },
              password: { type: :string },
              password_confirmation: { type: :string },
              current_password: { type: :string }
            }
          }
        }
      }

      response '200', 'user updated' do
        run_test! skip: 'documented route; Devise writes to session in this API-only test harness'
      end
    end

    delete 'Delete user registration' do
      tags 'Users'
      parameter name: 'Authorization', in: :header, type: :string

      response '204', 'user deleted' do
        run_test! skip: 'documented route; Devise writes to session in this API-only test harness'
      end
    end
  end

  path '/users/sign_in' do
    post 'Sign in' do
      tags 'Users'
      consumes 'application/json'
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, format: :email },
              password: { type: :string }
            },
            required: [ 'email', 'password' ]
          }
        }
      }

      response '200', 'signed in — JWT returned in the `Authorization: Bearer <token>` response header' do
        header 'Authorization', schema: { type: :string }, description: 'Bearer JWT token. Use this value as `Authorization: Bearer <token>` in subsequent requests.'
        let(:record) { create(:user, email: 'signin@example.com', password: 'password') }
        let(:user) { { user: { email: record.email, password: 'password' } } }
        run_test!
      end
    end
  end

  path '/users/sign_out' do
    delete 'Sign out' do
      tags 'Users'
      parameter name: 'Authorization', in: :header, type: :string

      response '204', 'signed out' do
        run_test! skip: 'documented route; Devise writes to session in this API-only test harness'
      end
    end
  end

  path '/users/password' do
    post 'Request password reset' do
      tags 'Users'
      consumes 'application/json'
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: { email: { type: :string, format: :email } },
            required: [ 'email' ]
          }
        }
      }

      response '200', 'reset instructions accepted' do
        let(:user) { { user: { email: 'user@example.com' } } }
        run_test!
      end
    end

    patch 'Reset password' do
      tags 'Users'
      consumes 'application/json'
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              reset_password_token: { type: :string },
              password: { type: :string },
              password_confirmation: { type: :string }
            },
            required: [ 'reset_password_token', 'password', 'password_confirmation' ]
          }
        }
      }

      response '200', 'password reset' do
        run_test! skip: 'documented route; reset token validity is handled by Devise'
      end
    end

    put 'Reset password' do
      tags 'Users'
      consumes 'application/json'
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              reset_password_token: { type: :string },
              password: { type: :string },
              password_confirmation: { type: :string }
            },
            required: [ 'reset_password_token', 'password', 'password_confirmation' ]
          }
        }
      }

      response '200', 'password reset' do
        run_test! skip: 'documented route; reset token validity is handled by Devise'
      end
    end
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
      consumes 'multipart/form-data'
      parameter name: 'listing[title]', in: :formData, type: :string
      parameter name: 'listing[description]', in: :formData, type: :string
      parameter name: 'listing[rv_type]', in: :formData, type: :string
      parameter name: 'listing[town]', in: :formData, type: :string
      parameter name: 'listing[state]', in: :formData, type: :string
      parameter name: 'listing[postcode]', in: :formData, type: :string
      parameter name: 'listing[price_per_day]', in: :formData, type: :number
      parameter name: 'listing[max_guests]', in: :formData, type: :integer
      parameter name: 'listing[images][]', in: :formData, type: :file

      parameter name: 'Authorization', in: :header, type: :string

      response '201', 'listing created' do
        let(:user) { create(:user, name: 'Rswag') }
        let(:Authorization) { "Bearer #{jwt_for(user)}" }
        let(:'listing[title]') { 'X' }
        let(:'listing[description]') { 'D' }
        let(:'listing[rv_type]') { 'caravan' }
        let(:'listing[town]') { 'Sydney' }
        let(:'listing[state]') { 'NSW' }
        let(:'listing[postcode]') { '2000' }
        let(:'listing[price_per_day]') { 100 }
        let(:'listing[max_guests]') { 2 }
        let(:'listing[images][]') { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/test.png"), "image/png") }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:'listing[title]') { nil }
        let(:'listing[description]') { nil }
        let(:'listing[rv_type]') { nil }
        let(:'listing[town]') { nil }
        let(:'listing[state]') { nil }
        let(:'listing[postcode]') { nil }
        let(:'listing[price_per_day]') { nil }
        let(:'listing[max_guests]') { nil }
        let(:'listing[images][]') { nil }
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
        let(:id) { create(:rv_listing).id }
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
      parameter name: :listing, in: :body, schema: LISTING_SCHEMA
      parameter name: 'Authorization', in: :header, type: :string

      response '200', 'listing updated' do
        let(:owner) { create(:user) }
        let(:listing_record) { create(:rv_listing, owner: owner) }
        let(:id) { listing_record.id }
        let(:Authorization) { "Bearer #{jwt_for(owner)}" }
        let(:listing) { { listing: { title: 'Updated Title' } } }
        run_test!
      end

      response '403', 'forbidden (non-owner)' do
        let(:owner) { create(:user) }
        let(:other) { create(:user) }
        let(:listing_record) { create(:rv_listing, owner: owner) }
        let(:id) { listing_record.id }
        let(:Authorization) { "Bearer #{jwt_for(other)}" }
        let(:listing) { { listing: { title: 'Hack' } } }
        run_test!
      end

      response '401', 'unauthorized (no token)' do
        let(:listing_record) { create(:rv_listing, owner: create(:user)) }
        let(:id) { listing_record.id }
        let(:Authorization) { nil }
        let(:listing) { { listing: { title: 'New' } } }
        run_test!
      end
    end

    patch 'Update listing' do
      tags 'Listings'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :id, in: :path, type: :integer
      parameter name: :listing, in: :body, schema: LISTING_SCHEMA
      parameter name: 'Authorization', in: :header, type: :string

      response '200', 'listing updated' do
        let(:owner) { create(:user) }
        let(:listing_record) { create(:rv_listing, owner: owner) }
        let(:id) { listing_record.id }
        let(:Authorization) { "Bearer #{jwt_for(owner)}" }
        let(:listing) { { listing: { title: 'Updated Title' } } }
        run_test!
      end
    end

    delete 'Delete listing' do
      tags 'Listings'
      parameter name: :id, in: :path, type: :integer
      parameter name: 'Authorization', in: :header, type: :string

      response '204', 'listing deleted' do
        let(:owner) { create(:user) }
        let(:listing_record) { create(:rv_listing, owner: owner) }
        let(:id) { listing_record.id }
        let(:Authorization) { "Bearer #{jwt_for(owner)}" }
        run_test!
      end

      response '403', 'forbidden (non-owner)' do
        let(:owner) { create(:user) }
        let(:other) { create(:user) }
        let(:listing_record) { create(:rv_listing, owner: owner) }
        let(:id) { listing_record.id }
        let(:Authorization) { "Bearer #{jwt_for(other)}" }
        run_test!
      end

      response '401', 'unauthorized (no token)' do
        let(:listing_record) { create(:rv_listing, owner: create(:user)) }
        let(:id) { listing_record.id }
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  path '/api/v1/listings/{listing_id}/images' do
    post 'Attach listing images' do
      tags 'Images'
      consumes 'multipart/form-data'
      parameter name: :listing_id, in: :path, type: :integer
      parameter name: 'Authorization', in: :header, type: :string
      parameter name: :images, in: :formData, type: :array, items: { type: :file }

      response '201', 'images attached' do
        let(:owner) { create(:user) }
        let(:listing) { create(:rv_listing, owner: owner) }
        let(:listing_id) { listing.id }
        let(:Authorization) { "Bearer #{jwt_for(owner)}" }
        let(:images) { [ Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test.png'), 'image/png') ] }
        run_test!
      end
    end
  end

  path '/api/v1/listings/{listing_id}/images/{id}' do
    delete 'Delete listing image' do
      tags 'Images'
      parameter name: :listing_id, in: :path, type: :integer
      parameter name: :id, in: :path, type: :integer
      parameter name: 'Authorization', in: :header, type: :string

      response '204', 'image deleted' do
        let(:owner) { create(:user) }
        let(:listing) { create(:rv_listing, owner: owner) }
        let(:listing_id) { listing.id }
        let(:id) do
          listing.images.attach(io: File.open(Rails.root.join('spec/fixtures/files/test.png')), filename: 'test.png', content_type: 'image/png')
          listing.images.attachments.last.id
        end
        let(:Authorization) { "Bearer #{jwt_for(owner)}" }
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
            required: [ 'start_date', 'end_date' ]
          }
        }
      }

      parameter name: 'Authorization', in: :header, type: :string

      response '201', 'booking created' do
        let(:owner) { create(:user) }
        let(:listing) { create(:rv_listing, owner: owner, title: 'x') }
        let(:hirer) { create(:user) }
        let(:listing_id) { listing.id }
        let(:Authorization) { "Bearer #{jwt_for(hirer)}" }
        let(:booking) { { booking: { start_date: Date.today + 1, end_date: Date.today + 2 } } }
        run_test!
      end

      response '403', 'forbidden' do
        # Owner attempting to book their own listing should receive 403
        let(:owner) { create(:user) }
        let(:listing) { create(:rv_listing, owner: owner, title: 'owned') }
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
        let(:listing) { create(:rv_listing, owner: owner, title: 'y', price_per_day: 20) }
        let(:booking) { create(:booking, rv_listing: listing, hirer: hirer, start_date: Date.today + 2, end_date: Date.today + 3, status: 'pending') }
        let(:id) { booking.id }
        let(:Authorization) { "Bearer #{jwt_for(owner)}" }
        run_test!
      end

      response '403', 'forbidden (non-owner)' do
        let(:owner) { create(:user) }
        let(:hirer) { create(:user) }
        let(:listing) { create(:rv_listing, owner: owner) }
        let(:booking) { create(:booking, rv_listing: listing, hirer: hirer, start_date: Date.today + 1, end_date: Date.today + 2, status: 'pending') }
        let(:id) { booking.id }
        let(:Authorization) { "Bearer #{jwt_for(hirer)}" }
        run_test!
      end

      response '401', 'unauthorized (no token)' do
        let(:owner) { create(:user) }
        let(:hirer) { create(:user) }
        let(:listing) { create(:rv_listing, owner: owner) }
        let(:booking) { create(:booking, rv_listing: listing, hirer: hirer, start_date: Date.today + 1, end_date: Date.today + 2, status: 'pending') }
        let(:id) { booking.id }
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  path '/api/v1/bookings/{id}/reject' do
    patch 'Reject booking' do
      tags 'Bookings'
      parameter name: :id, in: :path, type: :integer
      parameter name: 'Authorization', in: :header, type: :string

      response '200', 'booking rejected' do
        let(:owner) { create(:user) }
        let(:hirer) { create(:user) }
        let(:listing) { create(:rv_listing, owner: owner, title: 'z', price_per_day: 20) }
        let(:booking) { create(:booking, rv_listing: listing, hirer: hirer, start_date: Date.today + 2, end_date: Date.today + 3, status: 'pending') }
        let(:id) { booking.id }
        let(:Authorization) { "Bearer #{jwt_for(owner)}" }
        run_test!
      end

      response '403', 'forbidden (non-owner)' do
        let(:owner) { create(:user) }
        let(:hirer) { create(:user) }
        let(:listing) { create(:rv_listing, owner: owner) }
        let(:booking) { create(:booking, rv_listing: listing, hirer: hirer, start_date: Date.today + 1, end_date: Date.today + 2, status: 'pending') }
        let(:id) { booking.id }
        let(:Authorization) { "Bearer #{jwt_for(hirer)}" }
        run_test!
      end
    end
  end

  path '/api/v1/bookings' do
    get 'List bookings for current user' do
      tags 'Bookings'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string

      response '200', 'bookings listed' do
        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{jwt_for(user)}" }
        run_test!
      end
    end
  end

  path '/api/v1/chats' do
    get 'List chats for current user' do
      tags 'Chats'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string

      response '200', 'chats listed' do
        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{jwt_for(user)}" }
        run_test!
      end
    end
  end

  path '/api/v1/chats/{id}' do
    get 'Show chat' do
      tags 'Chats'
      produces 'application/json'
      parameter name: :id, in: :path, type: :integer
      parameter name: 'Authorization', in: :header, type: :string

      response '200', 'chat found' do
        let(:owner) { create(:user) }
        let(:hirer) { create(:user) }
        let(:listing) { create(:rv_listing, owner: owner) }
        let(:chat) { create(:chat, hirer: hirer, owner: owner, rv_listing: listing) }
        let(:id) { chat.id }
        let(:Authorization) { "Bearer #{jwt_for(hirer)}" }
        run_test!
      end
    end
  end

  path '/api/v1/listings/{listing_id}/chats' do
    post 'Start or resume a chat about a listing' do
      tags 'Chats'
      consumes 'application/json'
      parameter name: :listing_id, in: :path, type: :integer
      parameter name: :message, in: :body, schema: MESSAGE_SCHEMA
      parameter name: 'Authorization', in: :header, type: :string

      response '201', 'chat created' do
        let(:owner) { create(:user) }
        let(:listing) { create(:rv_listing, owner: owner, title: 'x') }
        let(:hirer) { create(:user) }
        let(:listing_id) { listing.id }
        let(:Authorization) { "Bearer #{jwt_for(hirer)}" }
        let(:message) { { message: { content: 'Is this available?' } } }
        run_test!
      end

      response '200', 'chat resumed (existing chat between same hirer and owner)' do
        let(:owner) { create(:user) }
        let(:listing) { create(:rv_listing, owner: owner, title: 'x') }
        let(:hirer) { create(:user) }
        let!(:existing_chat) { create(:chat, hirer: hirer, owner: owner, rv_listing: listing) }
        let(:listing_id) { listing.id }
        let(:Authorization) { "Bearer #{jwt_for(hirer)}" }
        let(:message) { { message: { content: 'Following up' } } }
        run_test!
      end
    end
  end

  path '/api/v1/chats/{chat_id}/messages' do
    get 'List messages in a chat' do
      tags 'Messages'
      produces 'application/json'
      parameter name: :chat_id, in: :path, type: :integer
      parameter name: 'Authorization', in: :header, type: :string

      response '200', 'messages listed' do
        let(:owner) { create(:user) }
        let(:hirer) { create(:user) }
        let(:listing) { create(:rv_listing, owner: owner) }
        let(:chat) { create(:chat, hirer: hirer, owner: owner, rv_listing: listing) }
        let(:chat_id) { chat.id }
        let(:Authorization) { "Bearer #{jwt_for(hirer)}" }
        run_test!
      end
    end

    post 'Send a message in a chat' do
      tags 'Messages'
      consumes 'application/json'
      parameter name: :chat_id, in: :path, type: :integer
      parameter name: :message, in: :body, schema: MESSAGE_SCHEMA
      parameter name: 'Authorization', in: :header, type: :string

      response '201', 'message created' do
        let(:owner) { create(:user) }
        let(:hirer) { create(:user) }
        let(:listing) { create(:rv_listing, owner: owner) }
        let(:chat) { create(:chat, hirer: hirer, owner: owner, rv_listing: listing) }
        let(:chat_id) { chat.id }
        let(:Authorization) { "Bearer #{jwt_for(hirer)}" }
        let(:message) { { message: { content: 'Any discount?' } } }
        run_test!
      end
    end
  end
end
