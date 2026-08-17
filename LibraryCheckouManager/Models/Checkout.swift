import Foundation

/// A single checked-out ebook, decoded from the Odilo `checkouts` endpoint.
/// Unrecognized JSON fields are simply ignored by `Decodable`.
struct Checkout: Decodable, Identifiable, Sendable, Equatable {
    let id: String
    let recordId: String
    let title: String
    let author: String
    let cover: String?
    let downloadUrl: String?
    let startTime: Int64
    let endTime: Int64
    let returnable: Bool
    let expired: Bool
    let formats: [String]
}

extension Checkout {
    var coverURL: URL? {
        guard let cover else { return nil }
        return URL(string: cover)
    }

    var dueDate: Date {
        Date(timeIntervalSince1970: Double(endTime) / 1000)
    }

    var dueDateText: String {
        dueDate.formatted(date: .abbreviated, time: .omitted)
    }

    /// Whether this checkout can be downloaded as an EPUB via `CB_DOWNLOAD`.
    var supportsDownload: Bool {
        downloadUrl != nil && formats.contains("CB_DOWNLOAD")
    }
}
