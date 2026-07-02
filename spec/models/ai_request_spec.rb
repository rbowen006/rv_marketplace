require 'rails_helper'

RSpec.describe AiRequest, type: :model do
  it "can be created with required attributes" do
    user = create(:user)
    record = AiRequest.create!(
      feature: "description_generator",
      model: "claude-sonnet-4-6",
      prompt_version: "v1",
      success: true,
      input_tokens: 100,
      output_tokens: 50,
      latency_ms: 800,
      estimated_cost_usd: 0.001050,
      user: user
    )
    expect(record).to be_persisted
    expect(record.feature).to eq("description_generator")
  end

  it "can be created without a user (background job context)" do
    record = AiRequest.create!(
      feature: "description_generator",
      model: "claude-sonnet-4-6",
      prompt_version: "v1",
      success: false,
      error_message: "API timeout"
    )
    expect(record).to be_persisted
    expect(record.user).to be_nil
  end
end
