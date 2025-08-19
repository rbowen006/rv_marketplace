require 'rails_helper'
require 'rswag/specs'

RSpec.configure do |config|
  # use new rswag-specs 3.0 config names to avoid deprecation warnings
  config.openapi_root = Rails.root.join('public', 'api-docs').to_s

  config.openapi_specs = {
    'v1/swagger.json' => {
      openapi: '3.0.1',
      info: {
        title: 'RV Marketplace API V1',
        version: 'v1'
      },
      paths: {}
    }
  }

  # Specify a format to generate
  config.openapi_format = :json
end
