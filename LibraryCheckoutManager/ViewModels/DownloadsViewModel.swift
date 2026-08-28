import Foundation
import Observation

@MainActor
@Observable
final class DownloadsViewModel {
    private(set) var downloads: [DownloadedBook] = []

    private(set) var sendingBookID: String?
    var kindleSendError: String?
    var kindleSendConfirmation: String?

    private let fileStore = EbookFileStore()
    private let resendClient = ResendEmailClient()

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

    func sendToKindle(_ book: DownloadedBook) async {
        guard let credentials = await ResendCredentialsStore.shared.load() else {
            kindleSendError = "Set up Send to Kindle in Settings first."
            return
        }
        sendingBookID = book.id
        defer { sendingBookID = nil }
        do {
            try await resendClient.sendToKindle(fileURL: fileStore.localURL(for: book), book: book, credentials: credentials)
            kindleSendConfirmation = "Sent \"\(book.title)\" to Kindle."
        } catch {
            kindleSendError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
