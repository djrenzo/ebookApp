import SwiftUI

/// Hero card showing the checked-out count at the top of the library.
struct LibraryHeroCard: View {
    let bookCount: Int
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "books.vertical.fill").font(.title2)
                Spacer()
                if isLoading {
                    ProgressView().tint(.white)
                }
            }
            Text(title).font(.title2.bold())
            Text("From your Odilo library account")
                .font(.subheadline)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LibraryTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var title: String {
        bookCount == 1 ? "1 book checked out" : "\(bookCount) books checked out"
    }
}

/// Inline banner shown when the checkouts request or a download fails.
struct LibraryErrorBanner: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Couldn't load your library").font(.subheadline.bold())
            }
            Text(message).font(.footnote).foregroundStyle(.secondary)
            Text("Update your session in the Settings tab.")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Placeholder shown when there are no current checkouts.
struct LibraryEmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Your shelf is empty").font(.headline)
            Text("Checked-out ebooks from your library account will show up here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
