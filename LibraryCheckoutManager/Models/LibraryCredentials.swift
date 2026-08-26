import Foundation

/// A signed-in patron session, obtained via `LibraryAuthService.login()`.
///
/// `JSESSIONID`/`AWSALB`/`AWSALBCORS` are deliberately not modeled here —
/// they're ordinary session cookies that `URLSession.shared`'s cookie jar
/// already tracks automatically from `Set-Cookie` responses, so nothing
/// needs to hand-carry or persist them.
struct LibraryCredentials: Sendable, Equatable {
    /// The patron's library card id.
    var patronId: String

    /// App-level Bearer token (from `OdiloAPIClient.fetchAppToken()`),
    /// used as `Authorization` on every call. Not tied to this patron.
    var appToken: String
    var appTokenExpiresAt: Date

    /// Per-patron access token, sent as the `OAuth-Token` header on
    /// mutating calls like checkout.
    var patronToken: String
    var patronTokenExpiresAt: Date

    /// Used by `LibraryAuthService.validCredentials()` to silently renew
    /// the patron session via `OdiloAPIClient.refreshPatronSession()`.
    /// Rotates on every refresh — the response's new value replaces this
    /// one, it isn't reused across refreshes.
    var patronRefreshToken: String

    var displayName: String
    var email: String
}

extension LibraryCredentials {
    var isAppTokenExpired: Bool {
        Date() >= appTokenExpiresAt
    }

    var isPatronTokenExpired: Bool {
        Date() >= patronTokenExpiresAt
    }
}
