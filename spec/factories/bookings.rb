FactoryBot.define do
  factory :booking do
    start_date { Date.today + 7 }
    end_date { Date.today + 10 }
    status { 'pending' }
    association :user
    association :rv_listing
  end
end
