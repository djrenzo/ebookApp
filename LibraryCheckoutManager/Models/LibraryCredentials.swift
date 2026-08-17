import Foundation

/// The patron ID plus session token/cookies needed to call the Odilo API.
/// These expire after a few days; Settings lets you paste fresh ones.
struct LibraryCredentials: Sendable, Equatable {
    var patronId: String
    var bearerToken: String
    var jsessionId: String
    var awsalb: String
    var awsalbcors: String

    /// The values captured from your account when this app was set up.
    /// Used to seed the Keychain the first time the app runs, so the
    /// Library screen and Settings work immediately without you having
    /// to look these up again.
    static let seeded = LibraryCredentials(
        patronId: "596270654",
        bearerToken: "50a6f2c98e136fac",
        jsessionId: "9233BC78A02EFF7C520E1FDA26B2BDBA",
        awsalb: "Dj60hphPYbji536KG59oNHQLzMdmmqXZV4W7xDWc18gM5jQoykq61fzbbE7QL1Vwr+8yaWKn3qUJVgcAMBOiGZvmuK4dbTA/A08Pfhc3GAkirrinKaPiwNtYQHzw",
        awsalbcors: "Dj60hphPYbji536KG59oNHQLzMdmmqXZV4W7xDWc18gM5jQoykq61fzbbE7QL1Vwr+8yaWKn3qUJVgcAMBOiGZvmuK4dbTA/A08Pfhc3GAkirrinKaPiwNtYQHzw"
    )
}
