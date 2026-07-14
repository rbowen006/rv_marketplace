require 'rails_helper'

RSpec.describe Ai::Tools::GetListingDetail do
  let(:listing) { create(:rv_listing, title: "Cozy van") }

  it "returns the listing's public detail" do
    result = described_class.call("listing_id" => listing.id)

    expect(result["id"]).to eq(listing.id)
    expect(result["title"]).to eq("Cozy van")
    expect(result).to include("price_per_day", "town", "owner")
    expect(result).not_to include("embedding", "region")
  end

  it "raises Ai::InputError for an unknown listing" do
    expect { described_class.call("listing_id" => -1) }.to raise_error(Ai::InputError)
  end
end
