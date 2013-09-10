module HTTP
  module Header
    # Matches HTTP header names when in "Canonical-Http-Format"
    CANONICAL_HEADER = /^[A-Z][a-z]*(-[A-Z][a-z]*)*$/

    # Transform to canonical HTTP header capitalization
    def canonicalize_header(header)
      header.to_s.split(/[\-_]/).map(&:capitalize).join('-')
    end
  end
end
