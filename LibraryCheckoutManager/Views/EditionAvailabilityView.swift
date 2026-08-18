import SwiftUI

/// Pushed when tapping a Hardcover edition — searches the Odilo catalog
/// for it (by ISBN when available, falling back to the book title) so you
/// can check whether the library has it to borrow. If an ISBN search comes
/// up empty, offers a one-tap fallback to search by the book's name instead.
struct EditionAvailabilityView: View {
    let query: String
    let titleQuery: String
    @State private var viewModel = SearchViewModel()

    var body: some View {
        CatalogSearchResultsView(
            viewModel: viewModel,
            emptyResultsAccessory: AnyView(tryWithNameButton)
        )
        .navigationTitle("Availability")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.query, prompt: "Search the catalog")
        .navigationDestination(for: SearchRecord.self) { record in
            BookDetailView(record: record)
        }
        .task { viewModel.query = query }
    }

    @ViewBuilder
    private var tryWithNameButton: some View {
        if viewModel.query != titleQuery {
            Button("Try with Name") {
                viewModel.query = titleQuery
            }
            .buttonStyle(.bordered)
        }
    }
}
