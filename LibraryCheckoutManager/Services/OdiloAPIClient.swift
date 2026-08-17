import Foundation

enum LibraryAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case missingDownloadURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The library returned an invalid address."
        case .invalidResponse:
            return "The library returned an unexpected response."
        case .httpError(let code):
            return "The library returned an error (code \(code)). Your session may have expired — update it in Settings."
        case .missingDownloadURL:
            return "This book doesn't have a download link available."
        }
    }
}

/// Talks to the Odilo library API: lists current checkouts and downloads
/// the EPUB for a checkout, manually following the cross-domain redirect so
/// the Authorization header survives the hop. Every request is reported to
/// `RequestLogger`, which only keeps it if logging is turned on.
struct OdiloAPIClient {
    private static let host = "onlinebibliotheek.odilotk.es"

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
        request.setValue(credentials.oauthToken, forHTTPHeaderField: "OAuth-Token")
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
        request.setValue("Bearer \(credentials.bearerToken)", forHTTPHeaderField: "Authorization")
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

    private func applyCommonHeaders(to request: inout URLRequest, credentials: LibraryCredentials) {
        request.setValue("Bearer \(credentials.bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(cookieHeader(credentials), forHTTPHeaderField: "Cookie")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
    }

    private func cookieHeader(_ credentials: LibraryCredentials) -> String {
        "JSESSIONID=\(credentials.jsessionId); AWSALB=\(credentials.awsalb); AWSALBCORS=\(credentials.awsalbcors)"
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