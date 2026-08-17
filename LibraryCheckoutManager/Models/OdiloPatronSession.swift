import Foundation

/// Response from `POST /opac/api/v2/login/external`, completing the KB SSO
/// login: the patron's id, and the per-patron access token used as the
/// `OAuth-Token` header on mutating calls like checkout.
struct OdiloPatronSession: Decodable, Sendable, Equatable {
    let id: String
    let name: String?
    let email: String?
    let session: String
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}
