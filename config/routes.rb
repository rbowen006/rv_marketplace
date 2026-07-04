Rails.application.routes.draw do
  if Rails.env.development? || Rails.env.test?
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end

  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations',
    passwords: 'users/passwords'
  }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api do
    namespace :v1 do
      resources :listings do
        resources :images, only: [:create, :destroy]
        resources :bookings, only: [:create]
        resources :chats, only: [:create]
        collection do
          get :mine
          post :search
          post :generate_description, to: 'description_generator#create'
        end
      end

      resources :chats, only: [:index, :show] do
        resources :messages, only: [:index, :create]
      end

      resources :bookings, only: [:index] do
        member do
          patch :confirm
          patch :reject
        end
      end
    end
  end
end
