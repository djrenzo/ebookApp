import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            CatalogSearchResultsView(viewModel: viewModel)
                .navigationTitle("Search")
                .searchable(text: $viewModel.query, prompt: "Search the catalog")
                .navigationDestination(for: SearchRecord.self) { record in
                    BookDetailView(record: record)
                }
        }
    }
}
