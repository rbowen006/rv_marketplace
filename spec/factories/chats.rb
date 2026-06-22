FactoryBot.define do
  factory :chat do
    association :hirer, factory: :user
    association :owner, factory: :user
    association :rv_listing
  end
end
