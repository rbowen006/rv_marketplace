require 'rails_helper'

RSpec.describe Ai::TripPlanner do
  let(:owner)   { create(:user) }
  let(:hirer)   { create(:user) }
  let(:listing) { create(:rv_listing, owner: owner, town: 'Lorne', state: 'VIC', postcode: '3232') }
  # Relative future dates so the Booking past-date validation always passes;
  # assertions below depend on the span (2 nights), not the absolute dates.
  let(:booking) do
    create(:booking, rv_listing: listing, hirer: hirer, status: 'confirmed',
                     start_date: Date.current + 1.week, end_date: Date.current + 9.days)
  end

  let(:query_embedding) { Array.new(768) { 0.05 } }

  let(:itinerary_json) do
    {
      summary: "Two relaxed days along the coast.",
      disclaimer: "Suggestions only — confirm opening hours and conditions locally.",
      days: [
        { date: "2026-07-10", title: "Beaches and lookouts",
          segments: [ { part_of_day: "morning", activity: "Lorne main beach", detail: "Calm and patrolled." } ] }
      ]
    }.to_json
  end

  let(:anthropic_success_body) do
    { id: "msg_1", type: "message", role: "assistant",
      content: [ { type: "text", text: itinerary_json } ],
      model: "claude-sonnet-4-6", stop_reason: "end_turn",
      usage: { input_tokens: 500, output_tokens: 120 } }.to_json
  end

  before do
    stub_request(:post, "http://ollama:11434/api/embeddings")
      .to_return(status: 200, body: { embedding: query_embedding }.to_json,
                 headers: { "Content-Type" => "application/json" })
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: anthropic_success_body,
                 headers: { "Content-Type" => "application/json" })

    KnowledgeChunk.create!(region: 'great-ocean-road', heading: 'Beaches', content: 'Lorne main beach is calm.',
                           embedding: Array.new(768) { 0.05 }, model: 'nomic-embed-text', content_hash: 'a')
    KnowledgeChunk.create!(region: 'great-ocean-road', heading: 'Walks', content: 'Erskine Falls track.',
                           embedding: Array.new(768) { 0.9 }, model: 'nomic-embed-text', content_hash: 'b')
  end

  # Parses the JSON payload the service sent to Claude (the user turn's content).
  def sent_payload
    captured = nil
    expect(
      a_request(:post, "https://api.anthropic.com/v1/messages").with { |req| captured = req.body; true }
    ).to have_been_made
    JSON.parse(JSON.parse(captured)["messages"].first["content"])
  end

  it "returns a validated day-by-day itinerary and logs a trip_plan request" do
    expect {
      result = described_class.call(booking: booking, interests: "quiet beaches", user: hirer)
      expect(result["summary"]).to eq("Two relaxed days along the coast.")
      expect(result["days"].first["date"]).to eq("2026-07-10")
    }.to change(AiRequest, :count).by(2) # query embedding + generation

    generation = AiRequest.where(feature: "trip_plan").order(:id).last
    expect(generation.success).to be true
    expect(generation.user).to eq(hirer)
  end

  it "grounds the prompt in the region's retrieved knowledge and destination" do
    described_class.call(booking: booking, interests: "quiet beaches", user: hirer)

    payload = sent_payload
    expect(payload["destination"]["region"]).to eq("Great Ocean Road")
    expect(payload["destination"]["town"]).to eq("Lorne")
    expect(payload["interests"]).to eq("quiet beaches")
    expect(payload["knowledge"].map { |k| k["heading"] }).to include("Beaches")
  end

  it "caps planned days at MAX_PLANNED_DAYS and reports the remaining nights" do
    long = create(:booking, rv_listing: listing, hirer: hirer, status: 'confirmed',
                            start_date: Date.current + 1.week, end_date: Date.current + 27.days) # 20 nights

    described_class.call(booking: long, user: hirer)

    dates = sent_payload["dates"]
    expect(dates["plan_dates"].length).to eq(7)
    expect(dates["additional_nights"]).to eq(13) # 20 nights - 7 planned
  end

  it "parses the itinerary even when Claude wraps the JSON in a markdown code fence" do
    fenced = "```json\n#{itinerary_json}\n```"
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
      status: 200,
      body: { id: "m", type: "message", role: "assistant",
              content: [ { type: "text", text: fenced } ],
              model: "claude-sonnet-4-6", stop_reason: "end_turn",
              usage: { input_tokens: 10, output_tokens: 10 } }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    result = described_class.call(booking: booking, interests: "beaches", user: hirer)
    expect(result["summary"]).to eq("Two relaxed days along the coast.")
  end

  it "raises the token ceiling above the base default for multi-day output" do
    described_class.call(booking: booking, user: hirer)

    body = nil
    expect(
      a_request(:post, "https://api.anthropic.com/v1/messages").with { |req| body = JSON.parse(req.body); true }
    ).to have_been_made
    expect(body["max_tokens"]).to eq(2048)
  end
end
