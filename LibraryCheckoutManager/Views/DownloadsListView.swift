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
                .alert(
                    "Sent to Kindle",
                    isPresented: Binding(
                        get: { viewModel.kindleSendConfirmation != nil },
                        set: { if !$0 { viewModel.kindleSendConfirmation = nil } }
                    )
                ) {
                    Button("OK") { viewModel.kindleSendConfirmation = nil }
                } message: {
                    Text(viewModel.kindleSendConfirmation ?? "")
                }
                .alert(
                    "Couldn't Send to Kindle",
                    isPresented: Binding(
                        get: { viewModel.kindleSendError != nil },
                        set: { if !$0 { viewModel.kindleSendError = nil } }
                    )
                ) {
                    Button("OK") { viewModel.kindleSendError = nil }
                } message: {
                    Text(viewModel.kindleSendError ?? "")
                }
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
        return DownloadedBookRow(
            book: book,
            fileURL: fileURL,
            isSendingToKindle: viewModel.sendingBookID == book.id,
            onOpen: {
                if !EPUBOpener.shared.open(fileURL) { previewURL = fileURL }
            },
            onSendToKindle: {
                Task { await viewModel.sendToKindle(book) }
            }
        )
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.delete(book)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

