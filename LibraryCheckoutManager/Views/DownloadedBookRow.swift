import SwiftUI

struct DownloadedBookRow: View {
    let book: DownloadedBook
    let fileURL: URL
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            cover
            info
            Spacer(minLength: 8)
            actions
        }
        .padding(.vertical, 6)
    }

    private var cover: some View {
        AsyncImage(url: book.coverURL) { phase in
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
            Text(book.title).font(.headline).lineLimit(2)
            Text(book.author).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            Text("Saved \(book.downloadedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        HStack(spacing: 16) {
            Button(action: onOpen) {
                Image(systemName: "book.fill")
            }
            ShareLink(item: fileURL) {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .font(.title3)
        .tint(LibraryTheme.accent)
        .buttonStyle(.plain)
    }
}
