require 'rails_helper'

RSpec.describe Ai::Tools::CheckAvailability do
  let(:listing) { create(:rv_listing) }

  # Relative future dates so bookings pass the Booking past-date validation.
  # The query window and the overlapping booking keep their original offsets
  # (query days 1–5, booking days 3–7) so the overlap semantics are unchanged.
  let(:query_start)   { Date.current + 1.week }
  let(:query_end)     { query_start + 4 }
  let(:overlap_start) { query_start + 2 }
  let(:overlap_end)   { query_start + 6 }

  def check(start_date, end_date, id: listing.id)
    described_class.call("listing_id" => id, "start_date" => start_date, "end_date" => end_date)
  end

  it "reports available when nothing overlaps the range" do
    expect(check(query_start.iso8601, query_end.iso8601)).to eq(available: true)
  end

  it "reports unavailable when an active booking overlaps" do
    create(:booking, rv_listing: listing, status: 'confirmed',
                     start_date: overlap_start, end_date: overlap_end)

    expect(check(query_start.iso8601, query_end.iso8601)).to eq(available: false)
  end

  it "ignores cancelled and rejected bookings" do
    create(:booking, rv_listing: listing, status: 'cancelled',
                     start_date: overlap_start, end_date: overlap_end)

    expect(check(query_start.iso8601, query_end.iso8601)).to eq(available: true)
  end

  it "raises Ai::InputError for an unknown listing" do
    expect { check(query_start.iso8601, query_end.iso8601, id: -1) }.to raise_error(Ai::InputError)
  end
end
