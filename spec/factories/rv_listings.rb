FactoryBot.define do
  factory :rv_listing do
    title { "Listing #{Faker::Vehicle.make_and_model}" }
    description { Faker::Lorem.sentence }
    location { Faker::Address.city }
    price_per_day { 100.0 }
    association :user
  end
end
