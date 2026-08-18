import SwiftUI

/// Pushed when tapping a Hardcover edition — searches the Odilo catalog
/// for it. Tries the ISBN first for a precise match; if that comes up
/// empty, silently retries with the book's name before ever showing a "no
/// results" state, so a fruitless ISBN search doesn't flash an empty
/// screen before the more forgiving name search runs. Only shown as "no
/// results" if the name search also comes up empty.
struct EditionAvailabilityView: View {
    let query: String
    let titleQuery: String
    @State private var viewModel = SearchViewModel()

    var body: some View {
        CatalogSearchResultsView(viewModel: viewModel)
            .navigationTitle("Availability")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, prompt: "Search the catalog")
            .navigationDestination(for: SearchRecord.self) { record in
                BookDetailView(record: record)
            }
            .task {
                await viewModel.searchImmediately(query)
                if viewModel.results.isEmpty && query != titleQuery {
                    await viewModel.searchImmediately(titleQuery)
                }
            }
    }
}
