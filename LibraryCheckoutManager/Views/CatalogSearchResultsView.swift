import SwiftUI

/// Shared results UI for a live Odilo catalog search — the query/loading/
/// paging state all live in `SearchViewModel`, so this view is reusable
/// both by the Search tab itself and by any other flow that wants to seed
/// a search (e.g. checking library availability for a Hardcover edition)
/// without embedding its own `NavigationStack`.
struct CatalogSearchResultsView: View {
    var viewModel: SearchViewModel

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
                ContentUnavailableView.search(text: viewModel.query)
            } else {
                resultsList
            }
        }
    }

    private var resultsList: some View {
        List {
            Section("\(viewModel.results.count) results") {
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
