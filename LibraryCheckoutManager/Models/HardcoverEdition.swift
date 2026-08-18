import Foundation

struct HardcoverEdition: Decodable, Sendable, Identifiable {
    let id: Int
    let isbn10: String?
    let isbn13: String?
    let image: HardcoverImage?
    let language: HardcoverLanguage?

    enum CodingKeys: String, CodingKey {
        case id
        case isbn10 = "isbn_10"
        case isbn13 = "isbn_13"
        case image, language
    }
}

struct HardcoverLanguage: Decodable, Sendable {
    let language: String
}

extension HardcoverEdition {
    var coverURL: URL? {
        image?.url.flatMap(URL.init(string:))
    }
}

struct HardcoverEditionsResponse: Decodable, Sendable {
    struct DataBody: Decodable, Sendable {
        let editions: [HardcoverEdition]
    }
    let data: DataBody
}
