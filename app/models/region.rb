# A trip-planning Region (ADR-0013): a sub-state area with an authored knowledge
# corpus. A PORO, not ActiveRecord — the vocabulary is static reference data read
# from app/knowledge/regions.yml, never CRUD'd at runtime.
class Region
  MANIFEST_PATH = Rails.root.join("app", "knowledge", "regions.yml")

  attr_reader :slug, :name, :state, :towns, :doc

  def initialize(slug:, name:, state:, towns: [], doc: nil)
    @slug  = slug
    @name  = name
    @state = state
    @towns = towns
    @doc   = doc
  end

  def self.all
    manifest.map { |attrs| new(**attrs.symbolize_keys) }
  end

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
