FactoryBot.define do
  factory :rv_listing do
    title { "Listing #{Faker::Vehicle.make_and_model}" }
    description { Faker::Lorem.sentence }
    rv_type { :caravan }
    town { Faker::Address.city }
    state { 'NSW' }
    postcode { '2000' }
    price_per_day { 100.0 }
    max_guests { 4 }
    pet_friendly { false }
    association :owner, factory: :user

    after(:build) do |listing|
      listing.images.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test.png")),
        filename: "test.png",
        content_type: "image/png"
      )
    end
  end
end
