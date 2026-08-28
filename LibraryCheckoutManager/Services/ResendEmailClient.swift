import Foundation

enum ResendEmailError: LocalizedError {
    case invalidResponse
    case httpError(Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Resend returned an unexpected response."
        case .httpError(let code, let message):
            let detail = message.map { ": \($0)" } ?? ""
            return "Resend couldn't send the email (code \(code))\(detail). Check your API key, From address, and Kindle address in Settings."
        }
    }
}

/// Emails a downloaded EPUB to a Kindle "Send to Kindle" address
/// (`...@kindle.com`) via Resend's transactional email API
/// (api.resend.com) — a separate, unrelated service from Odilo/KB and
/// Hardcover, using its own user-supplied API key. Kindle has accepted
/// EPUB attachments natively (no MOBI/AZW3 conversion) since December
/// 2022, so this is a plain attachment, not a special "convert" request.
/// Same request-logging pattern as `OdiloAPIClient`/`HardcoverAPIClient`.
struct ResendEmailClient {
    private static let endpoint = URL(string: "https://api.resend.com/emails")!

    func sendToKindle(fileURL: URL, book: DownloadedBook, credentials: ResendCredentials) async throws {
        let data = try Data(contentsOf: fileURL)

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ResendSendEmailBody(
            from: credentials.fromEmail,
            to: [credentials.kindleEmail],
            subject: book.title,
            text: "Sent from Ebookify.",
            attachments: [ResendAttachment(filename: fileURL.lastPathComponent, content: data.base64EncodedString())]
        ))

        let (responseData, http) = try await performLogged(request)
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ResendErrorBody.self, from: responseData))?.message
            throw ResendEmailError.httpError(http.statusCode, message: message)
        }
    }

    private func performLogged(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let start = Date()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ResendEmailError.invalidResponse }
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

private struct ResendSendEmailBody: Encodable {
    let from: String
    let to: [String]
    let subject: String
    let text: String
    let attachments: [ResendAttachment]
}

private struct ResendAttachment: Encodable {
    let filename: String
    let content: String
}

private struct ResendErrorBody: Decodable {
    let message: String?
}
