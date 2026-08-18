import Foundation
import Observation

@MainActor
@Observable
final class HardcoverEditionsViewModel {
    private(set) var editions: [HardcoverEdition] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let apiClient = HardcoverAPIClient()

    func load(bookId: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            guard let credentials = await HardcoverCredentialsStore.shared.load() else {
                throw HardcoverAPIError.notAuthenticated
            }
            editions = try await apiClient.fetchEditions(bookId: bookId, token: credentials.token)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}
