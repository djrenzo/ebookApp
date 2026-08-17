import Foundation

/// A single logged network call, with sensitive header values masked.
struct RequestLogEntry: Identifiable, Equatable, Sendable {
    let id = UUID()
    let timestamp: Date
    let method: String
    let url: String
    let requestHeaders: [String: String]
    var statusCode: Int?
    var responseHeaders: [String: String] = [:]
    var responseSummary: String?
    var errorMessage: String?
    var durationMs: Int = 0
}

/// Opt-in capture of the requests this app makes to the library, so users
/// can see exactly what was sent and received while debugging session or
/// download problems. Entries live only in memory for the current session;
/// nothing is written to disk.
@MainActor
@Observable
final class RequestLogger {
    static let shared = RequestLogger()

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    private(set) var entries: [RequestLogEntry] = []

    private static let enabledKey = "requestLoggingEnabled"
    private let maxEntries = 50

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    func clear() {
        entries.removeAll()
    }

    func record(
        method: String,
        url: String,
        requestHeaders: [String: String],
        start: Date,
        response: HTTPURLResponse?,
        responseBody: Data?,
        error: Error?
    ) {
        guard isEnabled else { return }
        var entry = RequestLogEntry(
            timestamp: start,
            method: method,
            url: url,
            requestHeaders: Self.redacted(requestHeaders),
            statusCode: response?.statusCode,
            durationMs: Int(Date().timeIntervalSince(start) * 1000)
        )
        entry.responseHeaders = Self.redacted(Self.headerDictionary(from: response))
        entry.responseSummary = Self.summary(for: responseBody, response: response)
        entry.errorMessage = error?.localizedDescription

        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    private static func headerDictionary(from response: HTTPURLResponse?) -> [String: String] {
        guard let response else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                result[key] = value
            }
        }
        return result
    }

    private static let sensitiveHeaderKeys: Set<String> = ["authorization", "cookie", "set-cookie"]

    private static func redacted(_ headers: [String: String]) -> [String: String] {
        headers.reduce(into: [String: String]()) { result, pair in
            let (key, value) = pair
            result[key] = sensitiveHeaderKeys.contains(key.lowercased()) ? mask(value) : value
        }
    }

    private static func mask(_ value: String) -> String {
        guard value.count > 6 else { return "•••" }
        return "•••\(value.suffix(4))"
    }

    private static func summary(for data: Data?, response: HTTPURLResponse?) -> String? {
        guard let data else { return nil }
        let contentType = response?.value(forHTTPHeaderField: "Content-Type") ?? ""
        if contentType.contains("json") || contentType.contains("text"), let text = String(data: data, encoding: .utf8) {
            return text.count > 800 ? "\(text.prefix(800))…" : text
        }
        return "\(data.count) bytes (\(contentType.isEmpty ? "binary" : contentType))"
    }
}
