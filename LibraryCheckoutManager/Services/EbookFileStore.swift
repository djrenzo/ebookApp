import Foundation

/// Saves downloaded EPUBs under `Documents/Ebooks/`, which is exposed as a
/// browsable folder in the Files app (see `UIFileSharingEnabled` and
/// `LSSupportsOpeningDocumentsInPlace` in project.yml). Metadata (title,
/// author, cover) is kept in a small JSON manifest in Application Support
/// instead, so the visible folder only ever contains the user's own EPUBs.
struct EbookFileStore {
    private let directory: URL
    private let manifestURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = documents.appendingPathComponent("Ebooks", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        manifestURL = support.appendingPathComponent("manifest.json")

        // Earlier builds kept the manifest alongside the EPUBs; migrate it
        // out of the now-visible folder so it doesn't show up in Files.
        let legacyManifestURL = directory.appendingPathComponent("manifest.json")
        if !FileManager.default.fileExists(atPath: manifestURL.path),
           FileManager.default.fileExists(atPath: legacyManifestURL.path) {
            try? FileManager.default.moveItem(at: legacyManifestURL, to: manifestURL)
        }
    }

    func loadManifest() -> [DownloadedBook] {
        guard let data = try? Data(contentsOf: manifestURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let books = try? decoder.decode([DownloadedBook].self, from: data)
        return (books ?? []).sorted { $0.downloadedAt > $1.downloadedAt }
    }

    func entry(for checkoutId: String) -> DownloadedBook? {
        loadManifest().first { $0.id == checkoutId }
    }

    func isDownloaded(_ checkoutId: String) -> Bool {
        entry(for: checkoutId) != nil
    }

    /// Looks up the file location for a checkout by id (used while browsing
    /// live checkouts, where only the id is known).
    func localURL(for checkoutId: String) -> URL? {
        entry(for: checkoutId).map { directory.appendingPathComponent($0.fileName) }
    }

    /// Resolves the file location directly from an already-loaded record
    /// (used in Downloads, which works from the manifest itself).
    func localURL(for book: DownloadedBook) -> URL {
        directory.appendingPathComponent(book.fileName)
    }

    @discardableResult
    func save(_ data: Data, checkout: Checkout) throws -> URL {
        let fileName = Self.fileName(title: checkout.title, id: checkout.id)
        let fileURL = directory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)

        let record = DownloadedBook(
            id: checkout.id,
            title: checkout.title,
            author: checkout.byline,
            coverURLString: checkout.cover,
            fileName: fileName,
            downloadedAt: Date()
        )
        var manifest = loadManifest().filter { $0.id != checkout.id }
        manifest.append(record)
        try writeManifest(manifest)
        return fileURL
    }

    func delete(_ checkoutId: String) throws {
        guard let record = entry(for: checkoutId) else { return }
        let fileURL = directory.appendingPathComponent(record.fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try writeManifest(loadManifest().filter { $0.id != checkoutId })
    }

    private func writeManifest(_ manifest: [DownloadedBook]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
    }

    /// A readable, unique file name so exported files look like
    /// "Liften-naar-de-hemel-2048270983.epub" instead of a bare id.
    private static func fileName(title: String, id: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let cleaned = title.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        var collapsed = String(cleaned)
        while collapsed.contains("--") {
            collapsed = collapsed.replacingOccurrences(of: "--", with: "-")
        }
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = trimmed.isEmpty ? "book" : String(trimmed.prefix(60))
        return "\(base)-\(id).epub"
    }
}