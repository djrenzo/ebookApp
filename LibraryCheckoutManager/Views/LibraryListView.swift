import SwiftUI
import QuickLook

struct LibraryListView: View {
    @Environment(LibraryViewModel.self) private var viewModel
    @State private var hardcoverViewModel = HardcoverShelfViewModel()
    @State private var previewURL: URL?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("My Library")
                .quickLookPreview($previewURL)
                .navigationDestination(for: HardcoverBook.self) { book in
                    HardcoverBookDetailView(book: book)
                }
                .task { await viewModel.loadCheckouts() }
                .task { await hardcoverViewModel.refresh() }
        }
    }

    private var content: some View {
        List {
            headerSection
            if let error = viewModel.loadError {
                errorSection(error)
            }
            booksSection
            hardcoverSections
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.loadCheckouts()
            await hardcoverViewModel.refresh()
        }
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

    @ViewBuilder
    private var hardcoverSections: some View {
        if hardcoverViewModel.isConnected {
            if !hardcoverViewModel.wantToRead.isEmpty {
                Section("Want to Read") {
                    ForEach(hardcoverViewModel.wantToRead) { userBook in
                        NavigationLink(value: userBook.book) {
                            HardcoverBookRow(book: userBook.book)
                        }
                    }
                }
            }
            if !hardcoverViewModel.currentlyReading.isEmpty {
                Section("Currently Reading") {
                    ForEach(hardcoverViewModel.currentlyReading) { userBook in
                        NavigationLink(value: userBook.book) {
                            HardcoverBookRow(book: userBook.book)
                        }
                    }
                }
            }
            if let message = hardcoverViewModel.errorMessage {
                errorSection(message)
            }
        }
    }

    private func bookRow(_ checkout: Checkout) -> some View {
        BookRowView(
            checkout: checkout,
            state: viewModel.downloadStates[checkout.id] ?? .notDownloaded,
            onDownload: { Task { await viewModel.download(checkout) } },
            onOpen: {
                guard let url = viewModel.localFileURL(for: checkout) else { return }
                if !EPUBOpener.shared.open(url) { previewURL = url }
            }
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
