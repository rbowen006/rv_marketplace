module Knowledge
  # Splits a region's markdown corpus into one chunk per H2 section (ADR-0013).
  # Anything before the first `##` (HTML comments, the H1 title, preamble) is
  # dropped; sections with no body text are skipped. Returns
  # [{ heading:, content: }] in document order.
  class DocumentChunker
    H2 = /\A##\s+(.+?)\s*\z/

    def self.call(markdown)
      new(markdown).call
    end

    def initialize(markdown)
      @markdown = markdown.to_s
    end

    def call
      sections = []
      current = nil

      @markdown.each_line do |line|
        if (match = line.match(H2))
          current = { heading: match[1], lines: [] }
          sections << current
        elsif current
          current[:lines] << line
        end
      end

      sections
        .map { |section| { heading: section[:heading], content: section[:lines].join.strip } }
        .reject { |section| section[:content].empty? }
    end
  end
end
