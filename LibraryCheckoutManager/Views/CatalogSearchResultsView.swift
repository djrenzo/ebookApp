import SwiftUI

/// Shared results UI for a live Odilo catalog search — the query/loading/
/// paging state all live in `SearchViewModel`, so this view is reusable
/// both by the Search tab itself and by any other flow that wants to seed
/// a search (e.g. checking library availability for a Hardcover edition)
/// without embedding its own `NavigationStack`.
struct CatalogSearchResultsView: View {
    var viewModel: SearchViewModel

    /// Extra content shown under the "no results" state — e.g. a "Try with
    /// Name" fallback when a flow seeded the search with an ISBN. Empty by
    /// default so the plain Search tab doesn't need to opt out of anything.
    var emptyResultsAccessory: AnyView = AnyView(EmptyView())

    var body: some View {
        Group {
            if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(
                    "Search the Library",
                    systemImage: "magnifyingglass",
                    description: Text("Find ebooks and audiobooks across your library's full catalog.")
                )
            } else if let message = viewModel.errorMessage, viewModel.results.isEmpty {
                List { errorSection(message) }.listStyle(.insetGrouped)
            } else if viewModel.results.isEmpty && !viewModel.isSearching {
                VStack(spacing: 20) {
                    ContentUnavailableView.search(text: viewModel.query)
                    emptyResultsAccessory
                }
            } else {
                resultsList
            }
        }
    }

    private var resultsList: some View {
        List {
            Section("\(viewModel.total) results") {
                ForEach(viewModel.results) { record in
                    NavigationLink(value: record) {
                        SearchResultRow(record: record)
                    }
                    .onAppear { viewModel.loadMoreIfNeeded(currentItem: record) }
                }
            }
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .top) {
            if viewModel.isSearching {
                ProgressView().padding(.top, 8)
            }
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            LibraryErrorBanner(title: "Search failed", message: message)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
