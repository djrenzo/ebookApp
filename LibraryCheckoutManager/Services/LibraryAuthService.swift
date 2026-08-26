import AuthenticationServices
import UIKit

enum LibraryAuthError: LocalizedError {
    case cancelled
    case missingCode

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Login was cancelled."
        case .missingCode:
            return "The library login didn't return an authorization code."
        }
    }
}

/// Runs the full KB SSO → Odilo login flow: fetches an app-level token,
/// asks Odilo for the KB login URL, runs the login itself in a system
/// browser sheet (so KB's real login page handles credentials, MFA, or
/// anything else it needs, and this app never sees the password), then
/// exchanges the resulting authorization code for a patron session.
@MainActor
final class LibraryAuthService: NSObject {
    static let shared = LibraryAuthService()

    /// Reuses the official app's registered callback scheme, which is
    /// already proven to round-trip through KB's login flow. Odilo does
    /// echo back whatever `callback` value is sent, so this app's own
    /// scheme may well work too, but that's unverified — this is the
    /// known-good option.
    private static let callbackScheme = "online.bibliotheek"
    private static let callbackURL = "online.bibliotheek://oauth"

    private let apiClient = OdiloAPIClient()
    private var webAuthSession: ASWebAuthenticationSession?

    func login() async throws -> LibraryCredentials {
        let appToken = try await apiClient.fetchAppToken()
        let loginURL = try await apiClient.requestExternalLoginURL(callback: Self.callbackURL, appToken: appToken.token)
        let resultURL = try await runWebAuthSession(url: loginURL)

        guard let components = URLComponents(url: resultURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let state = components.queryItems?.first(where: { $0.name == "state" })?.value else {
            throw LibraryAuthError.missingCode
        }

        let patronSession = try await apiClient.completeExternalLogin(code: code, state: state, appToken: appToken.token)

        return LibraryCredentials(
            patronId: patronSession.id,
            appToken: appToken.token,
            appTokenExpiresAt: Date().addingTimeInterval(TimeInterval(appToken.expiresIn)),
            patronToken: patronSession.accessToken,
            patronTokenExpiresAt: Date().addingTimeInterval(TimeInterval(patronSession.expiresIn)),
            patronRefreshToken: patronSession.refreshToken,
            displayName: patronSession.name ?? "",
            email: patronSession.email ?? ""
        )
    }

    /// Returns credentials for making API calls, transparently refreshing
    /// the app-level token and/or the patron token if either is expired.
    /// Returns `nil` if there's no signed-in patron. If the refresh call
    /// itself fails (e.g. the refresh token has also expired or been
    /// revoked), that error propagates — callers fall back to the existing
    /// "surface an auth error, prompt to log in again" behavior.
    func validCredentials() async throws -> LibraryCredentials? {
        guard var credentials = await CredentialsStore.shared.load() else { return nil }

        if credentials.isAppTokenExpired {
            let appToken = try await apiClient.fetchAppToken()
            credentials.appToken = appToken.token
            credentials.appTokenExpiresAt = Date().addingTimeInterval(TimeInterval(appToken.expiresIn))
            await CredentialsStore.shared.updateAppToken(appToken.token, expiresAt: credentials.appTokenExpiresAt)
        }

        if credentials.isPatronTokenExpired {
            let patronSession = try await apiClient.refreshPatronSession(
                refreshToken: credentials.patronRefreshToken,
                appToken: credentials.appToken
            )
            credentials.patronToken = patronSession.accessToken
            credentials.patronTokenExpiresAt = Date().addingTimeInterval(TimeInterval(patronSession.expiresIn))
            credentials.patronRefreshToken = patronSession.refreshToken
            await CredentialsStore.shared.updatePatronSession(
                accessToken: credentials.patronToken,
                expiresAt: credentials.patronTokenExpiresAt,
                refreshToken: credentials.patronRefreshToken
            )
        }

        return credentials
    }

    func logout() async {
        await CredentialsStore.shared.clear()
    }

    private func runWebAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: Self.callbackScheme) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if let error, case ASWebAuthenticationSessionError.canceledLogin = error {
                    continuation.resume(throwing: LibraryAuthError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? LibraryAuthError.missingCode)
                }
            }
            session.presentationContextProvider = self
            webAuthSession = session
            session.start()
        }
    }
}

extension LibraryAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
