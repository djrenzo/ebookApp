import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .searchable(text: $viewModel.query, prompt: "Search the catalog")
                .navigationDestination(for: SearchRecord.self) { record in
                    BookDetailView(record: record)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
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
            LibraryErrorBanner(message: message)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
