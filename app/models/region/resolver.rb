class Region
  # Resolves a listing's location to a Region slug (ADR-0013). The single place
  # town/postcode -> region lives, so rv_listings.region is set canonically
  # rather than by string matching scattered at query time.
  class Resolver
    def self.call(town:, state: nil, postcode: nil)
      new(town: town, state: state, postcode: postcode).call
    end

    def initialize(town:, state: nil, postcode: nil)
      @town     = town
      @state    = state
      @postcode = postcode
    end

    def call
      Region.all.find { |region| region.towns.include?(@town) }&.slug
    end
  end
end
