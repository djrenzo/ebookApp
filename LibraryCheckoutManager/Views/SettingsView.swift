import SwiftUI

struct SettingsView: View {
    @Bindable private var logger = RequestLogger.shared
    @State private var credentials: LibraryCredentials?
    @State private var isLoggingIn = false
    @State private var loginError: String?

    var body: some View {
        NavigationStack {
            Form {
                accountSection
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
}
