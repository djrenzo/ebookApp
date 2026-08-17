import Foundation
import Observation

enum BookDownloadState: Equatable {
    case notDownloaded
    case downloading
    case downloaded
    case failed(String)
}

@MainActor
@Observable
final class LibraryViewModel {
    private(set) var checkouts: [Checkout] = []
    private(set) var downloadStates: [String: BookDownloadState] = [:]
    private(set) var isLoading = false
    private(set) var loadError: String?

    private let apiClient = OdiloAPIClient()
    private let fileStore = EbookFileStore()

    func loadCheckouts() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let credentials = await CredentialsStore.shared.load()
            let fetched = try await apiClient.fetchCheckouts(credentials: credentials)
            checkouts = fetched
            for checkout in fetched {
                downloadStates[checkout.id] = fileStore.isDownloaded(checkout.id) ? .downloaded : .notDownloaded
            }
        } catch {
            loadError = message(for: error)
        }
    }

    func download(_ checkout: Checkout) async {
        downloadStates[checkout.id] = .downloading
        do {
            let credentials = await CredentialsStore.shared.load()
            let data = try await apiClient.downloadEPUB(for: checkout, credentials: credentials)
            try fileStore.save(data, checkout: checkout)
            downloadStates[checkout.id] = .downloaded
        } catch {
            downloadStates[checkout.id] = .failed(message(for: error))
        }
    }

    func removeDownload(_ checkout: Checkout) {
        try? fileStore.delete(checkout.id)
        downloadStates[checkout.id] = .notDownloaded
    }

    func localFileURL(for checkout: Checkout) -> URL? {
        fileStore.isDownloaded(checkout.id) ? fileStore.localURL(for: checkout.id) : nil
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
