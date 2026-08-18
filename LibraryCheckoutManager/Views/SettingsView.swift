import SwiftUI

struct SettingsView: View {
    @Bindable private var logger = RequestLogger.shared
    @State private var credentials: LibraryCredentials?
    @State private var isLoggingIn = false
    @State private var loginError: String?

    @State private var hardcover: HardcoverCredentials?
    @State private var hardcoverTokenInput = ""
    @State private var isConnectingHardcover = false
    @State private var hardcoverError: String?

    private let hardcoverAPIClient = HardcoverAPIClient()

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                hardcoverSection
                debuggingSection
            }
            .navigationTitle("Settings")
            .task { await refreshStatus() }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section("Account") {
            if let credentials {
                LabeledContent("Patron ID", value: credentials.patronId)
                if !credentials.displayName.isEmpty {
                    LabeledContent("Name", value: credentials.displayName)
                }
                if !credentials.email.isEmpty {
                    LabeledContent("Email", value: credentials.email)
                }
                Button("Log Out", role: .destructive) { Task { await logout() } }
            } else {
                Button {
                    Task { await login() }
                } label: {
                    if isLoggingIn {
                        ProgressView()
                    } else {
                        Text("Log In")
                    }
                }
                .disabled(isLoggingIn)
            }
        }

        if let loginError {
            Section {
                LibraryErrorBanner(message: loginError)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var hardcoverSection: some View {
        Section("Hardcover") {
            if let hardcover {
                LabeledContent("Username", value: hardcover.username)
                LabeledContent("User ID", value: String(hardcover.userId))
                Button("Disconnect", role: .destructive) { Task { await disconnectHardcover() } }
            } else {
                LabeledCredentialField(title: "Bearer Token", text: $hardcoverTokenInput)
                Button {
                    Task { await connectHardcover() }
                } label: {
                    if isConnectingHardcover {
                        ProgressView()
                    } else {
                        Text("Connect")
                    }
                }
                .disabled(isConnectingHardcover || hardcoverTokenInput.isEmpty)
            }
        }

        if let hardcoverError {
            Section {
                LibraryErrorBanner(message: hardcoverError)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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

    private func refreshStatus() async {
        credentials = await CredentialsStore.shared.load()
        hardcover = await HardcoverCredentialsStore.shared.load()
    }

    private func login() async {
        isLoggingIn = true
        loginError = nil
        do {
            let session = try await LibraryAuthService.shared.login()
            await CredentialsStore.shared.save(session)
            credentials = session
        } catch {
            loginError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoggingIn = false
    }

    private func logout() async {
        await LibraryAuthService.shared.logout()
        credentials = nil
    }

    private func connectHardcover() async {
        isConnectingHardcover = true
        hardcoverError = nil
        do {
            let profile = try await hardcoverAPIClient.fetchProfile(token: hardcoverTokenInput)
            let saved = HardcoverCredentials(token: hardcoverTokenInput, userId: profile.id, username: profile.username)
            await HardcoverCredentialsStore.shared.save(saved)
            hardcover = saved
            hardcoverTokenInput = ""
        } catch {
            hardcoverError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isConnectingHardcover = false
    }

    private func disconnectHardcover() async {
        await HardcoverCredentialsStore.shared.clear()
        hardcover = nil
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
