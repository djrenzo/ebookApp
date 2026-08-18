import Foundation

struct HardcoverEdition: Decodable, Sendable, Identifiable {
    let id: Int
    /// This edition's own title — can differ from the parent book's title
    /// (e.g. a translated or regional edition), so it's preferred over
    /// `HardcoverBook.title` when searching the library for this specific
    /// edition.
    let title: String?
    let isbn10: String?
    let isbn13: String?
    let editionFormat: String?
    let image: HardcoverImage?
    let language: HardcoverLanguage?

    enum CodingKeys: String, CodingKey {
        case id, title
        case isbn10 = "isbn_10"
        case isbn13 = "isbn_13"
        case editionFormat = "edition_format"
        case image, language
    }
}

struct HardcoverLanguage: Decodable, Sendable {
    let language: String
}

extension HardcoverEdition {
    var coverURL: URL? {
        guard let url = image?.url else { return nil }
        return URL(string: url)
    }
}

struct HardcoverEditionsResponse: Decodable, Sendable {
    struct DataBody: Decodable, Sendable {
        let editions: [HardcoverEdition]
    }
    let data: DataBody
}
