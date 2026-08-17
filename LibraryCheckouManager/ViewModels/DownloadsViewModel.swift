import Foundation
import Observation

@MainActor
@Observable
final class DownloadsViewModel {
    private(set) var downloads: [DownloadedBook] = []

    private let fileStore = EbookFileStore()

    func refresh() {
        downloads = fileStore.loadManifest()
    }

    func delete(_ book: DownloadedBook) {
        try? fileStore.delete(book.id)
        refresh()
    }

    func fileURL(for book: DownloadedBook) -> URL {
        fileStore.localURL(for: book)
    }
}
