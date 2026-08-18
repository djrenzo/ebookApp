import Foundation

enum HardcoverAPIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case notAuthenticated
    case unexpectedData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Hardcover returned an unexpected response."
        case .httpError(let code):
            return "Hardcover returned an error (code \(code)). Check your Hardcover token in Settings."
        case .notAuthenticated:
            return "Connect your Hardcover account in Settings first."
        case .unexpectedData:
            return "Hardcover returned data in an unexpected shape."
        }
    }
}

/// Talks to Hardcover's GraphQL API (api.hardcover.app) using a
/// user-supplied personal access token — a separate, unrelated service
/// from the Odilo/KB library backend. Every request is reported to
/// `RequestLogger` like `OdiloAPIClient`'s calls.
struct HardcoverAPIClient {
    private static let endpoint = URL(string: "https://api.hardcover.app/v1/graphql")!

    func fetchProfile(token: String) async throws -> HardcoverProfile {
        let response: HardcoverMeResponse = try await execute(
            query: "query Me { me { id username } }",
            variables: EmptyVariables(),
            token: token
        )
        guard let me = response.data.me.first else { throw HardcoverAPIError.unexpectedData }
        return HardcoverProfile(id: me.id, username: me.username)
    }

    /// Fetches the signed-in user's shelf, filtered to status 1 (Want to
    /// Read) and 2 (Currently Reading) server-side.
    func fetchMyBooks(token: String) async throws -> [HardcoverUserBook] {
        let response: HardcoverUserBooksResponse = try await execute(
            query: """
            query GetMyBooks {
              me {
                user_books(where: {status_id: {_in: [1, 2]}}) {
                  status_id
                  book { id title image { url } contributions { author { name } } }
                }
              }
            }
            """,
            variables: EmptyVariables(),
            token: token
        )
        return response.data.me.first?.userBooks ?? []
    }

    func fetchEditions(bookId: Int, token: String) async throws -> [HardcoverEdition] {
        let response: HardcoverEditionsResponse = try await execute(
            query: """
            query GetBookEditions($bookId: Int!) {
              editions(where: {book_id: {_eq: $bookId}}) {
                id
                isbn_10
                isbn_13
                image { url }
                language { language }
              }
            }
            """,
            variables: BookIdVariables(bookId: bookId),
            token: token
        )
        return response.data.editions
    }

    private func execute<Variables: Encodable, Response: Decodable>(
        query: String,
        variables: Variables,
        token: String
    ) async throws -> Response {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GraphQLRequestBody(query: query, variables: variables))

        let (data, http) = try await performLogged(request)
        guard (200..<300).contains(http.statusCode) else { throw HardcoverAPIError.httpError(http.statusCode) }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func performLogged(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let start = Date()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw HardcoverAPIError.invalidResponse }
            await RequestLogger.shared.record(
                method: request.httpMethod ?? "POST",
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
                method: request.httpMethod ?? "POST",
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
}

private struct GraphQLRequestBody<Variables: Encodable>: Encodable {
    let query: String
    let variables: Variables
}

private struct EmptyVariables: Encodable {}

private struct BookIdVariables: Encodable {
    let bookId: Int
}
