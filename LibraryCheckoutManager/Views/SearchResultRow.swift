import SwiftUI

struct SearchResultRow: View {
    let record: SearchRecord

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            cover
            info
            Spacer(minLength: 8)
        }
        .padding(.vertical, 6)
    }

    private var cover: some View {
        AsyncImage(url: record.coverURL) { phase in
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
            Text(record.title).font(.headline).lineLimit(2)
            if let subtitle = record.subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            if !record.byline.isEmpty {
                Text(record.byline).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            formatBadge
        }
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
}
