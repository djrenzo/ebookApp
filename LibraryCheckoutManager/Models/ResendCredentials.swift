import Foundation

/// Configuration for emailing downloaded EPUBs to a Kindle "Send to Kindle"
/// address via Resend — a separate, unrelated service from Odilo/KB and
/// Hardcover, same as those two.
struct ResendCredentials: Sendable, Equatable {
    var apiKey: String
    var fromEmail: String
    var kindleEmail: String
}
