import SwiftUI

struct BookRowView: View {
    let checkout: Checkout
    let state: BookDownloadState
    let onDownload: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            cover
            info
            Spacer(minLength: 8)
            actionButton
        }
        .padding(.vertical, 6)
    }

    private var cover: some View {
        AsyncImage(url: checkout.coverURL) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay(Image(systemName: "book.closed").foregroundStyle(.secondary))
            }
        }
        .frame(width: 56, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(checkout.title).font(.headline).lineLimit(2)
            Text(checkout.byline).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            Text("Due \(checkout.dueDateText)").font(.caption).foregroundStyle(.secondary)
            if case .failed(let message) = state {
                Text(message).font(.caption2).foregroundStyle(.red).lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .notDownloaded, .failed:
            downloadButton
        case .downloading:
            ProgressView().frame(width: 32, height: 32)
        case .downloaded:
            Button(action: onOpen) {
                Label("Read", systemImage: "book.fill")
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderedProminent)
            .tint(LibraryTheme.accent)
        }
    }

    @ViewBuilder
    private var downloadButton: some View {
        if checkout.supportsDownload {
            Button(action: onDownload) {
                Image(systemName: "arrow.down.circle.fill").font(.title2)
            }
            .tint(LibraryTheme.accent)
        } else {
            Text("Unavailable").font(.caption).foregroundStyle(.secondary)
        }
    }
}