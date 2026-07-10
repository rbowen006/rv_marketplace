# A trip-planning Region (ADR-0013): a sub-state area with an authored knowledge
# corpus. A PORO, not ActiveRecord — the vocabulary is static reference data read
# from app/knowledge/regions.yml, never CRUD'd at runtime.
class Region
  MANIFEST_PATH = Rails.root.join("app", "knowledge", "regions.yml")

  # Raised when regions.yml violates a manifest invariant (ADR-0013). The
  # resolver picks the first region whose towns include a match, so a town listed
  # under two regions would silently resolve by file order — this fails loudly at
  # load instead.
  class ManifestError < StandardError; end

  attr_reader :slug, :name, :state, :towns, :doc

  def initialize(slug:, name:, state:, towns: [], doc: nil)
    @slug  = slug
    @name  = name
    @state = state
    @towns = towns
    @doc   = doc
  end

  def self.all
    manifest.map { |attrs| new(**attrs.symbolize_keys) }.tap { |regions| ensure_unique_towns!(regions) }
  end

  # Each town must resolve to exactly one region (ADR-0013). Enforced here, at the
  # single access point every path (resolver, coverage gate, chunk loading) goes
  # through, so a duplicate can never resolve silently.
  def self.ensure_unique_towns!(regions)
    duplicated = regions.flat_map(&:towns).tally.select { |_town, count| count > 1 }.keys
    return if duplicated.empty?

    raise ManifestError,
          "regions.yml maps #{duplicated.join(', ')} to more than one region; " \
          "each town must resolve to exactly one region (ADR-0013)."
  end
  private_class_method :ensure_unique_towns!

  def self.find(slug)
    all.find { |region| region.slug == slug }
  end

  def self.manifest
    YAML.safe_load_file(MANIFEST_PATH) || []
  end

  # True once this region's corpus has been embedded — i.e. there is something
  # to retrieve. This is the coverage gate for trip planning (ADR-0013): a
  # region with a doc but no chunks yet is not yet available.
  def has_corpus?
    KnowledgeChunk.where(region: slug).exists?
  end

  # The region's markdown corpus body, or nil if no doc is declared/present.
  def doc_body
    return nil if doc.blank?

    path = Rails.root.join("app", "knowledge", doc)
    File.exist?(path) ? File.read(path) : nil
  end
end
