import Foundation

/// A connected Hardcover account: a manually-pasted personal API token plus
/// the profile it resolved to, kept entirely separate from the Odilo/KB
/// session (`LibraryCredentials`) since Hardcover is an unrelated service.
struct HardcoverCredentials: Sendable, Equatable {
    var token: String
    var userId: Int
    var username: String
}
