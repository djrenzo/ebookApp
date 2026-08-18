import SwiftUI

struct HardcoverBookDetailView: View {
    let book: HardcoverBook
    @State private var viewModel = HardcoverEditionsViewModel()

    var body: some View {
        List {
            if let message = viewModel.errorMessage {
                Section {
                    LibraryErrorBanner(message: message)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if viewModel.editions.isEmpty && !viewModel.isLoading {
                ContentUnavailableView("No Editions Found", systemImage: "book.closed")
            } else {
                Section("\(viewModel.editions.count) editions") {
                    ForEach(viewModel.editions) { edition in
                        editionRow(edition)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                ProgressView().padding(.top, 8)
            }
        }
        .task { await viewModel.load(bookId: book.id) }
    }

    private func editionRow(_ edition: HardcoverEdition) -> some View {
        HStack(spacing: 14) {
            cover(for: edition)
            VStack(alignment: .leading, spacing: 4) {
                Text(edition.language?.language ?? "Unknown language").font(.subheadline)
                if let isbn13 = edition.isbn13 {
                    Text("ISBN-13: \(isbn13)").font(.caption).foregroundStyle(.secondary)
                } else if let isbn10 = edition.isbn10 {
                    Text("ISBN-10: \(isbn10)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func cover(for edition: HardcoverEdition) -> some View {
        AsyncImage(url: edition.coverURL) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay(Image(systemName: "book.closed").font(.caption2).foregroundStyle(.secondary))
            }
        }
        .frame(width: 40, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
