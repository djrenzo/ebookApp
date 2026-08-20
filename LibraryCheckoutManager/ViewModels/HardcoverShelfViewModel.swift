import Foundation
import Observation

@MainActor
@Observable
final class HardcoverShelfViewModel {
    private(set) var isConnected = false
    private(set) var wantToRead: [HardcoverUserBook] = []
    private(set) var currentlyReading: [HardcoverUserBook] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let apiClient = HardcoverAPIClient()

    func refresh() async {
        guard let credentials = await HardcoverCredentialsStore.shared.load() else {
            isConnected = false
            wantToRead = []
            currentlyReading = []
            return
        }
        isConnected = true
        isLoading = true
        errorMessage = nil
        do {
            let books = try await apiClient.fetchMyBooks(token: credentials.token)
            wantToRead = books.filter { $0.statusId == 1 }.sortedByTitle()
            currentlyReading = books.filter { $0.statusId == 2 }.sortedByTitle()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}
