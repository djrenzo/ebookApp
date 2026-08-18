import SwiftUI

struct BookDetailView: View {
    let record: SearchRecord
    @State private var viewModel = BookDetailViewModel()
    @Environment(LibraryViewModel.self) private var libraryViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                checkoutButton
                if let message = viewModel.errorMessage {
                    LibraryErrorBanner(title: "Couldn't load this book", message: message, hint: nil)
                }
                if let message = viewModel.checkoutError {
                    LibraryErrorBanner(title: "Checkout failed", message: message, hint: nil)
                }
                if let description = viewModel.detail?.description, !description.isEmpty {
                    descriptionSection(description)
                }
                if let metadata = viewModel.detail?.metadata, !metadata.isEmpty {
                    metadataSection(metadata)
                }
                if viewModel.isLoading && viewModel.detail == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 20)
                }
            }
            .padding(20)
        }
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(id: record.id) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            cover
            VStack(alignment: .leading, spacing: 6) {
                Text(record.title).font(.title2.bold())
                if let subtitle = viewModel.detail?.subtitle ?? record.subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                if !byline.isEmpty {
                    Text(byline).font(.subheadline).foregroundStyle(.secondary)
                }
                formatBadge
            }
        }
    }

    private var byline: String {
        viewModel.detail?.byline ?? record.byline
    }

    private var checkoutButton: some View {
        Button {
            Task {
                if await viewModel.checkout(recordId: record.id) {
                    await libraryViewModel.loadCheckouts()
                }
            }
        } label: {
            Group {
                if viewModel.isCheckingOut {
                    ProgressView().tint(.white)
                } else if viewModel.didCheckOut {
                    Label("Checked Out", systemImage: "checkmark.circle.fill")
                } else {
                    Label("Checkout", systemImage: "arrow.down.circle")
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(LibraryTheme.accent)
        .disabled(viewModel.isCheckingOut || viewModel.didCheckOut)
    }

    private var cover: some View {
        AsyncImage(url: viewModel.detail?.coverURL ?? record.coverURL) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay(Image(systemName: "book.closed").font(.largeTitle).foregroundStyle(.secondary))
            }
        }
        .frame(width: 120, height: 172)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var formatBadge: some View {
        Text(record.isAudiobook ? "Audiobook" : "Ebook")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(LibraryTheme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(LibraryTheme.accent.opacity(0.15))
            .clipShape(Capsule())
    }

    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description").font(.headline)
            Text(text).font(.body).foregroundStyle(.secondary)
        }
    }

    private func metadataSection(_ groups: [RecordDetail.MetadataGroup]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details").font(.headline)
            VStack(spacing: 0) {
                ForEach(groups) { group in
                    metadataRow(group)
                    if group.id != groups.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func metadataRow(_ group: RecordDetail.MetadataGroup) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(group.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(group.values.map(\.text).joined(separator: ", "))
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}
