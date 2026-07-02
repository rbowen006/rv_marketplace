require 'rails_helper'

RSpec.describe "Ai exception hierarchy" do
  it "Ai::InputError is an Ai::Error" do
    expect(Ai::InputError.ancestors).to include(Ai::Error)
  end

  it "Ai::ApiError is an Ai::Error" do
    expect(Ai::ApiError.ancestors).to include(Ai::Error)
  end

  it "Ai::OutputError is an Ai::Error" do
    expect(Ai::OutputError.ancestors).to include(Ai::Error)
  end

  it "can rescue all subtypes with Ai::Error" do
    expect { raise Ai::InputError, "bad input" }.to raise_error(Ai::Error)
    expect { raise Ai::ApiError, "api down" }.to raise_error(Ai::Error)
    expect { raise Ai::OutputError, "bad output" }.to raise_error(Ai::Error)
  end
end
