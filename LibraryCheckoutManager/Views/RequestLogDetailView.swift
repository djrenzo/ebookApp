import SwiftUI

struct RequestLogDetailView: View {
    let entry: RequestLogEntry

    var body: some View {
        List {
            Section("Request") {
                LabeledLogValue(label: "Method", value: entry.method)
                LabeledLogValue(label: "URL", value: entry.url)
                LabeledLogValue(label: "Duration", value: "\(entry.durationMs) ms")
            }
            headersSection(title: "Request Headers", headers: entry.requestHeaders)
            Section("Response") {
                LabeledLogValue(label: "Status", value: entry.statusCode.map(String.init) ?? "No response")
                if let errorMessage = entry.errorMessage {
                    LabeledLogValue(label: "Error", value: errorMessage)
                }
            }
            headersSection(title: "Response Headers", headers: entry.responseHeaders)
            if let summary = entry.responseSummary {
                Section("Body") {
                    Text(summary).font(.system(.footnote, design: .monospaced))
                }
            }
        }
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func headersSection(title: String, headers: [String: String]) -> some View {
        if !headers.isEmpty {
            Section(title) {
                ForEach(headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    LabeledLogValue(label: key, value: value)
                }
            }
        }
    }
}

private struct LabeledLogValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.footnote, design: .monospaced))
        }
    }
}

