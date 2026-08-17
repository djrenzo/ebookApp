import Foundation
import Observation

@MainActor
@Observable
final class BookDetailViewModel {
    private(set) var detail: RecordDetail?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private(set) var isCheckingOut = false
    private(set) var checkoutError: String?
    private(set) var didCheckOut = false

    private let apiClient = OdiloAPIClient()

    func load(id: String) async {
        isLoading = true
        errorMessage = nil
        do {
            guard let credentials = try await LibraryAuthService.shared.validCredentials() else {
                throw LibraryAPIError.notAuthenticated
            }
            detail = try await apiClient.fetchRecordDetail(id: id, credentials: credentials)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    @discardableResult
    func checkout(recordId: String) async -> Bool {
        isCheckingOut = true
        checkoutError = nil
        defer { isCheckingOut = false }
        do {
            guard let credentials = try await LibraryAuthService.shared.validCredentials() else {
                throw LibraryAPIError.notAuthenticated
            }
            _ = try await apiClient.checkout(recordId: recordId, credentials: credentials)
            didCheckOut = true
            return true
        } catch {
            checkoutError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}
