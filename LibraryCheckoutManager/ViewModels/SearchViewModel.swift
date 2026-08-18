import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var query = "" {
        didSet { scheduleSearch() }
    }
    /// Ebooks only — Odilo's search mixes in audiobooks and reading lists,
    /// but this app only supports EPUBs, so audiobook records are filtered
    /// out before they ever reach the UI.
    private(set) var results: [SearchRecord] = []
    private(set) var total = 0
    private(set) var isSearching = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?

    private let apiClient = OdiloAPIClient()
    private let pageSize = 18
    private var searchTask: Task<Void, Never>?
    private var currentQuery = ""

    /// Raw records consumed from the server so far — used as the paging
    /// `offset`. Deliberately separate from `results.count`, since that's
    /// smaller once audiobooks are filtered out and would otherwise cause
    /// pagination to re-request/skip records incorrectly.
    private var fetchedCount = 0

    var hasMoreResults: Bool { fetchedCount < total }

    func clear() {
        searchTask?.cancel()
        query = ""
        results = []
        total = 0
        fetchedCount = 0
        errorMessage = nil
        isSearching = false
        isLoadingMore = false
    }

    /// Called as rows scroll into view; fetches the next page once the user
    /// nears the end of what's already loaded.
    func loadMoreIfNeeded(currentItem record: SearchRecord) {
        guard let index = results.firstIndex(of: record) else { return }
        guard index >= results.count - 4 else { return }
        Task { await loadNextPage() }
    }

    /// Runs a search immediately for `text`, skipping the debounce used for
    /// live typing — for callers that already know exactly what to search
    /// for (e.g. an automatic ISBN → name fallback) and don't want a delay
    /// or a redundant duplicate search firing later.
    func searchImmediately(_ text: String) async {
        query = text
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await performSearch(trimmed)
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            total = 0
            fetchedCount = 0
            errorMessage = nil
            isSearching = false
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self?.performSearch(trimmed)
        }
    }

    private func performSearch(_ text: String) async {
        currentQuery = text
        isSearching = true
        errorMessage = nil
        do {
            guard let credentials = try await LibraryAuthService.shared.validCredentials() else {
                throw LibraryAPIError.notAuthenticated
            }
            let response = try await apiClient.search(query: text, limit: pageSize, offset: 0, credentials: credentials)
            guard !Task.isCancelled, text == currentQuery else { return }
            fetchedCount = response.records.count
            total = response.total
            results = response.records.filter { !$0.isAudiobook }
        } catch {
            guard !Task.isCancelled, text == currentQuery else { return }
            results = []
            total = 0
            fetchedCount = 0
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isSearching = false
    }

    private func loadNextPage() async {
        guard !isSearching, !isLoadingMore, hasMoreResults else { return }
        let text = currentQuery
        guard !text.isEmpty else { return }

        isLoadingMore = true
        do {
            guard let credentials = try await LibraryAuthService.shared.validCredentials() else {
                throw LibraryAPIError.notAuthenticated
            }
            let response = try await apiClient.search(query: text, limit: pageSize, offset: fetchedCount, credentials: credentials)
            guard text == currentQuery else { return }
            fetchedCount += response.records.count
            total = response.total
            results.append(contentsOf: response.records.filter { !$0.isAudiobook })
        } catch {
            guard text == currentQuery else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoadingMore = false
    }
}
