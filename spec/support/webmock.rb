require 'webmock/rspec'

# Block all real outbound HTTP in tests. This is intentional — every external
# service call must be stubbed with stub_request(...). If a future test needs
# a real outbound call, use WebMock.allow_net_connect! scoped to that example.
WebMock.disable_net_connect!(allow_localhost: true)

# Force a dummy API key so ENV.fetch("ANTHROPIC_API_KEY") doesn't raise, and so
# a real key from the host/.env never leaks into request logs or failure output.
# Real HTTP to Anthropic is intercepted by stub_request in AI service specs.
ENV["ANTHROPIC_API_KEY"] = "test-key-for-specs"
