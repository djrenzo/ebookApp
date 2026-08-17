import Foundation

/// A locally saved EPUB, persisted independently of the live checkouts list
/// so it stays visible in Downloads even after a book is returned or expires.
struct DownloadedBook: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let author: String
    let coverURLString: String?
    let fileName: String
    let downloadedAt: Date

    var coverURL: URL? {
        coverURLString.flatMap(URL.init(string:))
    }
}
