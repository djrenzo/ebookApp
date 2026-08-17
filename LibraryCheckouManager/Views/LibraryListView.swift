import SwiftUI
import QuickLook

struct LibraryListView: View {
    @State private var viewModel = LibraryViewModel()
    @State private var previewURL: URL?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("My Library")
                .quickLookPreview($previewURL)
                .task { await viewModel.loadCheckouts() }
        }
    }

    private var content: some View {
        List {
            headerSection
            if let error = viewModel.loadError {
                errorSection(error)
            }
            booksSection
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.loadCheckouts() }
    }

    private var headerSection: some View {
        Section {
            LibraryHeroCard(bookCount: viewModel.checkouts.count, isLoading: viewModel.isLoading)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            LibraryErrorBanner(message: message)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var booksSection: some View {
        if viewModel.checkouts.isEmpty && !viewModel.isLoading {
            Section {
                LibraryEmptyState()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            Section("Checked out") {
                ForEach(viewModel.checkouts) { checkout in
                    bookRow(checkout)
                }
            }
        }
    }

    private func bookRow(_ checkout: Checkout) -> some View {
        BookRowView(
            checkout: checkout,
            state: viewModel.downloadStates[checkout.id] ?? .notDownloaded,
            onDownload: { Task { await viewModel.download(checkout) } },
            onOpen: { previewURL = viewModel.localFileURL(for: checkout) }
        )
        .swipeActions(edge: .trailing) {
            if viewModel.downloadStates[checkout.id] == .downloaded {
                Button(role: .destructive) {
                    viewModel.removeDownload(checkout)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
