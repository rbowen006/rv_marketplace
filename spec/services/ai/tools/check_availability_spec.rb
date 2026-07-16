require 'rails_helper'

RSpec.describe Ai::Tools::CheckAvailability do
  let(:listing) { create(:rv_listing) }

  def check(start_date, end_date, id: listing.id)
    described_class.call("listing_id" => id, "start_date" => start_date, "end_date" => end_date)
  end

  it "reports available when nothing overlaps the range" do
    expect(check("2026-09-01", "2026-09-05")).to eq(available: true)
  end

  it "reports unavailable when an active booking overlaps" do
    create(:booking, rv_listing: listing, status: 'confirmed',
                     start_date: Date.new(2026, 9, 3), end_date: Date.new(2026, 9, 7))

    expect(check("2026-09-01", "2026-09-05")).to eq(available: false)
  end

  it "ignores cancelled and rejected bookings" do
    create(:booking, rv_listing: listing, status: 'cancelled',
                     start_date: Date.new(2026, 9, 3), end_date: Date.new(2026, 9, 7))

    expect(check("2026-09-01", "2026-09-05")).to eq(available: true)
  end

  it "raises Ai::InputError for an unknown listing" do
    expect { check("2026-09-01", "2026-09-05", id: -1) }.to raise_error(Ai::InputError)
  end
end
