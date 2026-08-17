import Foundation

enum LibraryAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case missingDownloadURL
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The library returned an invalid address."
        case .invalidResponse:
            return "The library returned an unexpected response."
        case .httpError(let code):
            return "The library returned an error (code \(code)). Your session may have expired — log in again from Settings."
        case .missingDownloadURL:
            return "This book doesn't have a download link available."
        case .notAuthenticated:
            return "Log in from Settings to see your library."
        }
    }
}

/// Talks to the Odilo library API: lists current checkouts and downloads
/// the EPUB for a checkout, manually following the cross-domain redirect so
/// the Authorization header survives the hop. Every request is reported to
/// `RequestLogger`, which only keeps it if logging is turned on.
struct OdiloAPIClient {
    private static let host = "onlinebibliotheek.odilotk.es"

    /// The iOS app's own OAuth client credentials — embedded in every
    /// install of the official Bibliotheek app, not tied to any individual
    /// patron. This authenticates the *app*, not the user.
    private static let appClientAuthorization = "Basic aU9TX0FQUDo5bnY3OGVxQlYzeThmRG4="

    /// Exchanges the app's static client credentials for a Bearer token
    /// good for 24 hours (`expiresIn`). Doesn't require a patron to be
    /// logged in. The response's `Set-Cookie` headers (JSESSIONID, AWSALB,
    /// AWSALBCORS) are the same ones every other call needs, and land in
    /// `URLSession.shared`'s cookie storage automatically since every
    /// request in this client goes through it — no method needs to build a
    /// `Cookie` header by hand.
    func fetchAppToken() async throws -> OdiloAppToken {
        guard let url = URL(string: "https://\(Self.host)/opac/api/v2/token/") else {
            throw LibraryAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Self.appClientAuthorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.httpBody = Data("grant_type=client_credentials".utf8)

        let (data, http) = try await performLogged(request)
        guard (200..<300).contains(http.statusCode) else { throw LibraryAPIError.httpError(http.statusCode) }
        return try JSONDecoder().decode(OdiloAppToken.self, from: data)
    }

    /// Asks Odilo for the URL to open in a browser to run the KB SSO login.
    /// Odilo binds the returned `state` to the current app-level session
    /// (via the JSESSIONID cookie from `fetchAppToken()`) so it can
    /// recognize the login when the resulting code comes back.
    ///
    /// `callback` is echoed straight through as the KB `redirect_uri`, so
    /// it doesn't have to be the official app's `online.bibliotheek`
    /// scheme — this app registering its own custom scheme and passing
    /// that instead should work too (needs confirming against a real
    /// response before relying on it).
    ///
    /// Relies on `URLSession.shared`'s cookie jar already holding the
    /// JSESSIONID/AWSALB/AWSALBCORS cookies `fetchAppToken()` received, so
    /// no `Cookie` header is set by hand here.
    func requestExternalLoginURL(callback: String, appToken: String) async throws -> URL {
        var components = URLComponents(string: "https://\(Self.host)/opac/api/v2/login/external")
        components?.queryItems = [
            URLQueryItem(name: "callback", value: callback),
            URLQueryItem(name: "client", value: "app"),
            URLQueryItem(name: "type", value: "OAUTH2"),
        ]
        guard let url = components?.url else { throw LibraryAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        let (data, http) = try await performLogged(request)
        guard (200..<300).contains(http.statusCode) else { throw LibraryAPIError.httpError(http.statusCode) }

        let raw = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        guard let loginURL = URL(string: raw) else { throw LibraryAPIError.invalidResponse }
        return loginURL
    }

    /// Exchanges the authorization `code` from the KB redirect for a patron
    /// session: the patron id and a per-patron access token (used as the
    /// `OAuth-Token` header on mutating calls), plus a refresh token for
    /// renewing it later. `scope`/`iss`/`client_id` aren't extracted from
    /// anywhere — they're constants matching what was sent to start the
    /// flow, echoed back alongside the real `code`/`state`.
    func completeExternalLogin(code: String, state: String, appToken: String) async throws -> OdiloPatronSession {
        guard let url = URL(string: "https://\(Self.host)/opac/api/v2/login/external?type=OAUTH2&client=app") else {
            throw LibraryAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(ExternalLoginExchangeBody(state: state, code: code))

        let (data, http) = try await performLogged(request)
        guard (200..<300).contains(http.statusCode) else { throw LibraryAPIError.httpError(http.statusCode) }
        return try JSONDecoder().decode(OdiloPatronSession.self, from: data)
    }

    func fetchCheckouts(credentials: LibraryCredentials) async throws -> [Checkout] {
        guard let url = URL(string: "https://\(Self.host)/opac/api/v2/patrons/\(credentials.patronId)/checkouts") else {
            throw LibraryAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyCommonHeaders(to: &request, credentials: credentials)
        request.setValue("7", forHTTPHeaderField: "api-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, http) = try await performLogged(request)
        guard (200..<300).contains(http.statusCode) else { throw LibraryAPIError.httpError(http.statusCode) }
        return try JSONDecoder().decode([Checkout].self, from: data)
    }

    /// Fetches the full detail for a single catalog record, including the
    /// `metadata` groups the search endpoint omits.
    func fetchRecordDetail(id: String, credentials: LibraryCredentials) async throws -> RecordDetail {
        var components = URLComponents(string: "https://\(Self.host)/opac/api/v2/records/\(id)")
        components?.queryItems = [URLQueryItem(name: "enableMetadata", value: "true")]
        guard let url = components?.url else { throw LibraryAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyCommonHeaders(to: &request, credentials: credentials)
        request.setValue("6", forHTTPHeaderField: "api-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, http) = try await performLogged(request)
        guard (200..<300).contains(http.statusCode) else { throw LibraryAPIError.httpError(http.statusCode) }
        return try JSONDecoder().decode(RecordDetail.self, from: data)
    }

    /// Searches the library catalog (not just your own checkouts) via the
    /// `records` endpoint, ordered by relevance.
    func search(query: String, limit: Int = 18, offset: Int = 0, credentials: LibraryCredentials) async throws -> SearchResponse {
        var components = URLComponents(string: "https://\(Self.host)/opac/api/v2/records/")
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "order", value: "relevance:desc"),
            URLQueryItem(name: "limitFacetValues", value: "21"),
            URLQueryItem(name: "faceted", value: "true"),
            URLQueryItem(name: "lists", value: "true"),
            URLQueryItem(name: "showExperiences", value: "true"),
            URLQueryItem(name: "save", value: "true"),
            URLQueryItem(name: "query", value: "allfields_txt:\(query)"),
        ]
        guard let url = components?.url else { throw LibraryAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyCommonHeaders(to: &request, credentials: credentials)
        request.setValue("7", forHTTPHeaderField: "api-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, http) = try await performLogged(request)
        guard (200..<300).contains(http.statusCode) else { throw LibraryAPIError.httpError(http.statusCode) }
        return try JSONDecoder().decode(SearchResponse.self, from: data)
    }

    /// Checks out a catalog record to the patron, returning the new
    /// checkout's id, download URL, and due date.
    func checkout(recordId: String, credentials: LibraryCredentials) async throws -> CheckoutResult {
        guard let url = URL(string: "https://\(Self.host)/opac/api/v2/records/\(recordId)/checkout") else {
            throw LibraryAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(to: &request, credentials: credentials)
        request.setValue("7", forHTTPHeaderField: "api-version")
        request.setValue(credentials.patronToken, forHTTPHeaderField: "OAuth-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("from=SEARCH_SUGGEST&patronId=\(credentials.patronId)".utf8)

        let (data, http) = try await performLogged(request)
        guard (200..<300).contains(http.statusCode) else { throw LibraryAPIError.httpError(http.statusCode) }
        return try JSONDecoder().decode(CheckoutResult.self, from: data)
    }

    func downloadEPUB(for checkout: Checkout, credentials: LibraryCredentials) async throws -> Data {
        guard let downloadUrlString = checkout.downloadUrl,
              let firstURL = URL(string: downloadUrlString + "&format=CB_DOWNLOAD") else {
            throw LibraryAPIError.missingDownloadURL
        }

        var firstRequest = URLRequest(url: firstURL)
        firstRequest.httpMethod = "GET"
        applyCommonHeaders(to: &firstRequest, credentials: credentials)

        let redirectDelegate = RedirectCapturingDelegate()
        let (firstData, firstHTTP) = try await performLogged(firstRequest, delegate: redirectDelegate)

        if (200..<300).contains(firstHTTP.statusCode) {
            return firstData
        }

        guard (300..<400).contains(firstHTTP.statusCode),
              let location = redirectDelegate.capturedLocation,
              let secondURL = URL(string: location) else {
            throw LibraryAPIError.httpError(firstHTTP.statusCode)
        }

        return try await performDownloadRedirect(to: secondURL, credentials: credentials)
    }

    private func performDownloadRedirect(to url: URL, credentials: LibraryCredentials) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.appToken)", forHTTPHeaderField: "Authorization")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        let (data, http) = try await performLogged(request)
        guard (200..<300).contains(http.statusCode) else { throw LibraryAPIError.httpError(http.statusCode) }
        return data
    }

    /// Performs a request and reports it to `RequestLogger` regardless of
    /// outcome, so failures show up in the log too.
    private func performLogged(
        _ request: URLRequest,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let start = Date()
        do {
            let (data, response) = try await URLSession.shared.data(for: request, delegate: delegate)
            guard let http = response as? HTTPURLResponse else { throw LibraryAPIError.invalidResponse }
            await RequestLogger.shared.record(
                method: request.httpMethod ?? "GET",
                url: request.url?.absoluteString ?? "",
                requestHeaders: request.allHTTPHeaderFields ?? [:],
                start: start,
                response: http,
                responseBody: data,
                error: nil
            )
            return (data, http)
        } catch {
            await RequestLogger.shared.record(
                method: request.httpMethod ?? "GET",
                url: request.url?.absoluteString ?? "",
                requestHeaders: request.allHTTPHeaderFields ?? [:],
                start: start,
                response: nil,
                responseBody: nil,
                error: error
            )
            throw error
        }
    }

    /// Sets the app-level `Authorization` header. Session cookies
    /// (JSESSIONID/AWSALB/AWSALBCORS) are handled by `URLSession.shared`'s
    /// cookie jar automatically and deliberately not set here — see
    /// `fetchAppToken()`.
    private func applyCommonHeaders(to request: inout URLRequest, credentials: LibraryCredentials) {
        request.setValue("Bearer \(credentials.appToken)", forHTTPHeaderField: "Authorization")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
    }
}

private struct ExternalLoginExchangeBody: Encodable {
    let state: String
    let scope = "openid profile"
    let iss = "https://login.kb.nl/si/auth/oauth2.0/v1"
    let clientId = "odiloapp"
    let code: String

    enum CodingKeys: String, CodingKey {
        case state, scope, iss, code
        case clientId = "client_id"
    }
}

/// Intercepts the 307 redirect from the checkouts host to the CB download
/// host, capturing `Location` instead of letting URLSession auto-follow it
/// (which would strip the Authorization header on the cross-host hop).
private final class RedirectCapturingDelegate: NSObject, URLSessionTaskDelegate {
    nonisolated(unsafe) var capturedLocation: String?

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        capturedLocation = response.value(forHTTPHeaderField: "Location")
        return nil
    }
}