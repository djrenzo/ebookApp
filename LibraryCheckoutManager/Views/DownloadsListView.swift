import SwiftUI
import QuickLook

struct DownloadsListView: View {
    @State private var viewModel = DownloadsViewModel()
    @State private var previewURL: URL?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Downloads")
                .quickLookPreview($previewURL)
                .onAppear { viewModel.refresh() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.downloads.isEmpty {
            emptyState
        } else {
            List {
                ForEach(viewModel.downloads) { book in
                    row(for: book)
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Downloads Yet",
            systemImage: "arrow.down.circle",
            description: Text("Books you download from the Library tab are saved here so you can read or export them anytime.")
        )
    }

    private func row(for book: DownloadedBook) -> some View {
        let fileURL = viewModel.fileURL(for: book)
        return DownloadedBookRow(book: book, fileURL: fileURL) {
            if !EPUBOpener.shared.open(fileURL) { previewURL = fileURL }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.delete(book)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

