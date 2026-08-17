import SwiftUI

struct RootTabView: View {
    @State private var libraryViewModel = LibraryViewModel()

    var body: some View {
        TabView {
            LibraryListView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            DownloadsListView()
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(LibraryTheme.accent)
        .environment(libraryViewModel)
    }
}
