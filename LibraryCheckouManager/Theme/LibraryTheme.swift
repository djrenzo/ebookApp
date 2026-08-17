import SwiftUI

/// Shared visual language for the library: a plum-to-teal gradient evoking
/// a reading lamp at dusk, paired with a teal accent for actions.
enum LibraryTheme {
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.29, green: 0.22, blue: 0.55),
            Color(red: 0.11, green: 0.45, blue: 0.48),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accent = Color(red: 0.11, green: 0.45, blue: 0.48)
}
