require 'rails_helper'

RSpec.describe Ai::Tools::CalculatePrice do
  let(:listing) { create(:rv_listing, price_per_day: 150) }

  it "returns nights, nightly price, and total for a date range" do
    result = described_class.call(
      "listing_id" => listing.id,
      "start_date" => "2026-08-01",
      "end_date" => "2026-08-04"
    )

    expect(result).to eq(nights: 3, price_per_day: listing.price_per_day, total: 450)
  end

  it "raises Ai::InputError for an unknown listing" do
    expect {
      described_class.call("listing_id" => -1, "start_date" => "2026-08-01", "end_date" => "2026-08-04")
    }.to raise_error(Ai::InputError, /listing/)
  end

  it "raises Ai::InputError when end_date is not after start_date" do
    expect {
      described_class.call("listing_id" => listing.id, "start_date" => "2026-08-04", "end_date" => "2026-08-01")
    }.to raise_error(Ai::InputError)
  end
end
