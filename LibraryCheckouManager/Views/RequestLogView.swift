import SwiftUI

struct RequestLogView: View {
    @Bindable private var logger = RequestLogger.shared

    var body: some View {
        List {
            if logger.entries.isEmpty {
                emptyState
            } else {
                ForEach(logger.entries) { entry in
                    NavigationLink {
                        RequestLogDetailView(entry: entry)
                    } label: {
                        RequestLogRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("Request Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear", role: .destructive) { logger.clear() }
                    .disabled(logger.entries.isEmpty)
            }
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text(logger.isEnabled ? "No requests yet" : "Logging is off").font(.headline)
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var emptyMessage: String {
        logger.isEnabled
            ? "Requests the app makes to your library will show up here."
            : "Turn on \"Log network requests\" above to start capturing requests and responses."
    }
}

private struct RequestLogRow: View {
    let entry: RequestLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                statusBadge
                Text(entry.method).font(.caption.bold())
                Spacer()
                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(entry.url).font(.footnote).lineLimit(2)
        }
    }

    private var statusBadge: some View {
        let text = entry.statusCode.map(String.init) ?? "ERR"
        let color: Color = switch entry.statusCode {
        case .some(let code) where (200..<300).contains(code): .green
        case .some(let code) where (300..<400).contains(code): .blue
        default: .red
        }
        return Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

