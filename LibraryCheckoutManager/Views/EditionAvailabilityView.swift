import SwiftUI

/// Pushed when tapping a Hardcover edition — searches the Odilo catalog
/// for it (by ISBN when available, falling back to the book title) so you
/// can check whether the library has it to borrow.
struct EditionAvailabilityView: View {
    let query: String
    @State private var viewModel = SearchViewModel()

    var body: some View {
        CatalogSearchResultsView(viewModel: viewModel)
            .navigationTitle("Availability")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, prompt: "Search the catalog")
            .navigationDestination(for: SearchRecord.self) { record in
                BookDetailView(record: record)
            }
            .task { viewModel.query = query }
    }
}
