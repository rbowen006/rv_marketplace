require 'rails_helper'

RSpec.describe Ai::Tools::RecommendListings do
  it "acks the recommended ids when all are real listings" do
    a = create(:rv_listing)
    b = create(:rv_listing)

    result = described_class.call({ "listing_ids" => [a.id, b.id] })

    expect(result).to eq(recommended: [a.id, b.id])
  end

  it "raises Ai::InputError when any id is not a real listing" do
    a = create(:rv_listing)

    expect { described_class.call({ "listing_ids" => [a.id, -1] }) }
      .to raise_error(Ai::InputError, /-1/)
  end
end
