import Foundation
import Observation

@MainActor
@Observable
final class BookDetailViewModel {
    private(set) var detail: RecordDetail?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let apiClient = OdiloAPIClient()

    func load(id: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let credentials = await CredentialsStore.shared.load()
            detail = try await apiClient.fetchRecordDetail(id: id, credentials: credentials)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}
