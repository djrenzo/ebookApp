import Foundation

/// A single catalog entry from the Odilo `records` search endpoint. Missing
/// fields are tolerated since the endpoint returns a mix of ebooks,
/// audiobooks, and reading lists with different shapes.
struct SearchRecord: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let author: String?
    let narrators: [String]
    let coverImageUrl: String?
    let formats: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, author, narrators, coverImageUrl, formats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        narrators = try container.decodeIfPresent([String].self, forKey: .narrators) ?? []
        coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
        formats = try container.decodeIfPresent([String].self, forKey: .formats) ?? []
    }
}

extension SearchRecord {
    var coverURL: URL? {
        coverImageUrl.flatMap(URL.init(string:))
    }

    var isAudiobook: Bool {
        formats.contains("MP3") || formats.contains("AUDIO_ENCRYPTED")
    }

    /// "Author" for ebooks, "Author · narrated by X" for audiobooks.
    var byline: String {
        var parts: [String] = []
        if let author { parts.append(author) }
        if !narrators.isEmpty { parts.append("narrated by \(narrators.joined(separator: ", "))") }
        return parts.joined(separator: " · ")
    }
}

/// Response envelope from `/opac/api/v2/records/`. Facets are returned too
/// but aren't needed for a plain search bar, so they're left undecoded.
struct SearchResponse: Decodable, Sendable {
    let total: Int
    let records: [SearchRecord]
}
