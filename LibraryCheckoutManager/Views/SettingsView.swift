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

    @State private var resend: ResendCredentials?
    @State private var resendAPIKeyInput = ""
    @State private var resendFromEmailInput = ""
    @State private var resendKindleEmailInput = ""
    @State private var isSavingResend = false

    private let hardcoverAPIClient = HardcoverAPIClient()

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                hardcoverSection
                sendToKindleSection
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
                LibraryErrorBanner(title: "Login Failed", message: loginError, hint: nil)
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
                LibraryErrorBanner(title: "Connection Failed", message: hardcoverError, hint: nil)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var sendToKindleSection: some View {
        Section("Send to Kindle") {
            if let resend {
                LabeledContent("From", value: resend.fromEmail)
                LabeledContent("Kindle Address", value: resend.kindleEmail)
                Button("Disconnect", role: .destructive) { Task { await disconnectResend() } }
            } else {
                LabeledCredentialField(title: "Resend API Key", text: $resendAPIKeyInput)
                emailField(title: "From Email", text: $resendFromEmailInput)
                emailField(title: "Kindle Email", text: $resendKindleEmailInput)
                Button {
                    Task { await saveResend() }
                } label: {
                    if isSavingResend {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(isSavingResend || resendAPIKeyInput.isEmpty || resendFromEmailInput.isEmpty || resendKindleEmailInput.isEmpty)
            }
            Text("From Email must be a sender Amazon has approved under Manage Your Content and Devices → Preferences → Personal Document Settings, or your Kindle will reject the email.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func emailField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: text)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
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
        resend = await ResendCredentialsStore.shared.load()
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

    private func saveResend() async {
        isSavingResend = true
        let saved = ResendCredentials(
            apiKey: resendAPIKeyInput,
            fromEmail: resendFromEmailInput,
            kindleEmail: resendKindleEmailInput
        )
        await ResendCredentialsStore.shared.save(saved)
        resend = saved
        resendAPIKeyInput = ""
        resendFromEmailInput = ""
        resendKindleEmailInput = ""
        isSavingResend = false
    }

    private func disconnectResend() async {
        await ResendCredentialsStore.shared.clear()
        resend = nil
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
