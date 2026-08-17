import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            LibraryListView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
            DownloadsListView()
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(LibraryTheme.accent)
    }
}
