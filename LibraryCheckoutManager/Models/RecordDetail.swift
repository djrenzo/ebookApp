import Foundation

/// The full record returned by `/opac/api/v2/records/{id}`, including the
/// free-form `metadata` groups (publisher, language, ISBN, etc.) that the
/// search endpoint doesn't return.
struct RecordDetail: Decodable, Sendable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let author: String?
    let narrators: [String]
    let description: String?
    let coverImageUrl: String?
    let coverUrls: CoverURLs?
    let formats: [String]
    let subjects: [String]
    let metadata: [MetadataGroup]

    struct CoverURLs: Decodable, Sendable, Equatable {
        let small: String?
        let medium: String?
        let large: String?
        let xLarge: String?

        enum CodingKeys: String, CodingKey {
            case small, medium, large
            case xLarge = "x-large"
        }
    }

    struct MetadataGroup: Decodable, Sendable, Equatable, Identifiable {
        let label: String
        let values: [MetadataValue]
        var id: String { label }
    }

    struct MetadataValue: Decodable, Sendable, Equatable {
        let text: String
    }

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, author, narrators, description
        case coverImageUrl, coverUrls, formats, subjects, metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        narrators = try container.decodeIfPresent([String].self, forKey: .narrators) ?? []
        description = try container.decodeIfPresent(String.self, forKey: .description)
        coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
        coverUrls = try container.decodeIfPresent(CoverURLs.self, forKey: .coverUrls)
        formats = try container.decodeIfPresent([String].self, forKey: .formats) ?? []
        subjects = try container.decodeIfPresent([String].self, forKey: .subjects) ?? []
        metadata = try container.decodeIfPresent([MetadataGroup].self, forKey: .metadata) ?? []
    }
}

extension RecordDetail {
    var coverURL: URL? {
        (coverUrls?.xLarge ?? coverUrls?.large ?? coverImageUrl).flatMap(URL.init(string:))
    }

    var isAudiobook: Bool {
        formats.contains("MP3") || formats.contains("AUDIO_ENCRYPTED")
    }

    var byline: String {
        var parts: [String] = []
        if let author { parts.append(author) }
        if !narrators.isEmpty { parts.append("narrated by \(narrators.joined(separator: ", "))") }
        return parts.joined(separator: " · ")
    }
}
