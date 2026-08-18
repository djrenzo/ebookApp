import SwiftUI

struct HardcoverBookDetailView: View {
    let book: HardcoverBook
    @State private var viewModel = HardcoverEditionsViewModel()
    @State private var selectedLanguage: String?
    @State private var selectedFormat: String?

    private var languages: [String] {
        Array(Set(viewModel.editions.compactMap(\.language?.language))).sorted()
    }

    private var formats: [String] {
        Array(Set(viewModel.editions.compactMap(\.editionFormat))).sorted()
    }

    private var filteredEditions: [HardcoverEdition] {
        viewModel.editions.filter { edition in
            (selectedLanguage == nil || edition.language?.language == selectedLanguage)
                && (selectedFormat == nil || edition.editionFormat == selectedFormat)
        }
    }

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
                filtersSection
                Section("\(filteredEditions.count) editions") {
                    ForEach(filteredEditions) { edition in
                        NavigationLink(value: EditionSearchQuery(text: searchText(for: edition))) {
                            editionRow(edition)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: EditionSearchQuery.self) { request in
            EditionAvailabilityView(query: request.text)
        }
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                ProgressView().padding(.top, 8)
            }
        }
        .task { await viewModel.load(bookId: book.id) }
    }

    @ViewBuilder
    private var filtersSection: some View {
        if languages.count > 1 || formats.count > 1 {
            Section("Filter") {
                if languages.count > 1 {
                    Picker("Language", selection: $selectedLanguage) {
                        Text("All Languages").tag(String?.none)
                        ForEach(languages, id: \.self) { language in
                            Text(language).tag(String?.some(language))
                        }
                    }
                }
                if formats.count > 1 {
                    Picker("Format", selection: $selectedFormat) {
                        Text("All Formats").tag(String?.none)
                        ForEach(formats, id: \.self) { format in
                            Text(format).tag(String?.some(format))
                        }
                    }
                }
            }
        }
    }

    /// Prefer the ISBN for a precise match against the library catalog;
    /// fall back to the book title when an edition has neither.
    private func searchText(for edition: HardcoverEdition) -> String {
        edition.isbn13 ?? edition.isbn10 ?? book.title
    }

    private func editionRow(_ edition: HardcoverEdition) -> some View {
        HStack(spacing: 14) {
            cover(for: edition)
            VStack(alignment: .leading, spacing: 4) {
                Text(edition.language?.language ?? "Unknown language").font(.subheadline)
                if let format = edition.editionFormat {
                    Text(format).font(.caption).foregroundStyle(.secondary)
                }
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

private struct EditionSearchQuery: Hashable {
    let text: String
}
