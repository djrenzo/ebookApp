import Foundation

struct HardcoverBook: Decodable, Identifiable, Sendable, Hashable {
    let id: Int
    let title: String
    let image: HardcoverImage?
    let contributions: [HardcoverContribution]
}

struct HardcoverImage: Decodable, Sendable, Hashable {
    let url: String
}

struct HardcoverContribution: Decodable, Sendable, Hashable {
    let author: HardcoverAuthor
}

struct HardcoverAuthor: Decodable, Sendable, Hashable {
    let name: String
}

extension HardcoverBook {
    var coverURL: URL? {
        guard let url = image?.url else { return nil }
        return URL(string: url)
    }

    var authorNames: String {
        contributions.map(\.author.name).joined(separator: ", ")
    }
}

/// A book on the signed-in Hardcover user's shelf, from `GetMyBooks`.
/// `statusId` 1 = Want to Read, 2 = Currently Reading — the only two
/// statuses this app queries for.
struct HardcoverUserBook: Decodable, Sendable, Identifiable {
    let statusId: Int
    let book: HardcoverBook

    var id: Int { book.id }

    enum CodingKeys: String, CodingKey {
        case statusId = "status_id"
        case book
    }
}

struct HardcoverUserBooksResponse: Decodable, Sendable {
    struct DataBody: Decodable, Sendable {
        let me: [MeUserBooks]
    }
    struct MeUserBooks: Decodable, Sendable {
        let userBooks: [HardcoverUserBook]

        enum CodingKeys: String, CodingKey {
            case userBooks = "user_books"
        }
    }
    let data: DataBody
}
