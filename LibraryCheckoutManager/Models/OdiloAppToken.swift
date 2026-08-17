import Foundation

/// Response from `POST /opac/api/v2/token/` with `grant_type=client_credentials`
/// — an app-level Bearer token, unrelated to any specific patron.
struct OdiloAppToken: Decodable, Sendable, Equatable {
    let token: String
    let type: String
    let expiresIn: Int
}
