import SwiftUI

struct SettingsView: View {
    @Bindable private var logger = RequestLogger.shared
    @State private var patronId = ""
    @State private var bearerToken = ""
    @State private var jsessionId = ""
    @State private var awsalb = ""
    @State private var awsalbcors = ""
    @State private var isSaving = false
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Patron ID", text: $patronId)
                        .keyboardType(.numberPad)
                }
                Section("Session") {
                    LabeledCredentialField(title: "Bearer Token", text: $bearerToken)
                    LabeledCredentialField(title: "JSESSIONID", text: $jsessionId)
                    LabeledCredentialField(title: "AWSALB", text: $awsalb)
                    LabeledCredentialField(title: "AWSALBCORS", text: $awsalbcors)
                }
                Section {
                    Text("These come from a captured request to your library account and expire after a few days. Paste fresh values here when the Library screen starts showing errors.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                debuggingSection
            }
            .navigationTitle("Settings")
            .toolbar { toolbarContent }
            .task { await loadCurrent() }
        }
    }

    private var debuggingSection: some View {
        Section("Debugging") {
            Toggle("Log network requests", isOn: $logger.isEnabled)
            NavigationLink("View Request Log") {
                RequestLogView()
            }
            Text("When on, requests to your library and their responses are kept in memory (not on disk) so you can inspect them here. Authorization and cookie values are masked.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(didSave ? "Saved" : "Save") { Task { await save() } }
                .disabled(isSaving)
        }
    }

    private func loadCurrent() async {
        let credentials = await CredentialsStore.shared.load()
        patronId = credentials.patronId
        bearerToken = credentials.bearerToken
        jsessionId = credentials.jsessionId
        awsalb = credentials.awsalb
        awsalbcors = credentials.awsalbcors
    }

    private func save() async {
        isSaving = true
        let credentials = LibraryCredentials(
            patronId: patronId,
            bearerToken: bearerToken,
            jsessionId: jsessionId,
            awsalb: awsalb,
            awsalbcors: awsalbcors
        )
        await CredentialsStore.shared.save(credentials)
        isSaving = false
        didSave = true
        try? await Task.sleep(for: .seconds(1.5))
        didSave = false
    }
}

private struct LabeledCredentialField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: $text)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
}
