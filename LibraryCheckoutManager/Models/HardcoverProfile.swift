import Foundation

/// The signed-in Hardcover user, from `query { me { id username } }`.
struct HardcoverProfile: Sendable, Equatable {
    let id: Int
    let username: String
}

/// Raw response envelope for the profile query. Hardcover returns `me` as
/// a single-element array rather than a plain object.
struct HardcoverMeResponse: Decodable, Sendable {
    struct DataBody: Decodable, Sendable {
        let me: [Me]
    }
    struct Me: Decodable, Sendable {
        let id: Int
        let username: String
    }
    let data: DataBody
}
