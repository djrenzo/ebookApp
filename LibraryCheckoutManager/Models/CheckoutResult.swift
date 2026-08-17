import Foundation

/// The response from `POST /records/{id}/checkout`, confirming a new
/// checkout was created.
struct CheckoutResult: Decodable, Sendable, Equatable {
    let id: String
    let recordId: String
    let downloadUrl: String?
    let startTime: Int64
    let endTime: Int64
    let returnable: Bool
    let expired: Bool
    let formats: [String]
}

extension CheckoutResult {
    var dueDate: Date {
        Date(timeIntervalSince1970: Double(endTime) / 1000)
    }

    var dueDateText: String {
        dueDate.formatted(date: .abbreviated, time: .omitted)
    }
}
