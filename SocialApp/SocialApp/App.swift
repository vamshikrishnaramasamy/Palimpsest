import SwiftUI

@main
struct SocialApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            if auth.isAuthenticated {
                MainTabView()
                    .environmentObject(auth)
            } else {
                LoginView()
                    .environmentObject(auth)
            }
        }
    }
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: User? = nil
    @Published var isLoading = true
    @Published var error: String? = nil

    var isAuthenticated: Bool { user != nil }

    init() {
        Task { await checkAuth() }
    }

    func checkAuth() async {
        do {
            user = try await APIClient.shared.getMe()
        } catch {
            user = nil
        }
        isLoading = false
    }

    func signUp(email: String, password: String) async {
        do {
            let newUser = try await APIClient.shared.signUp(email: email, password: password)
            user = newUser
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        do {
            let loggedInUser = try await APIClient.shared.signIn(email: email, password: password)
            user = loggedInUser
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signInWithOAuth(provider: String, idToken: String, displayName: String? = nil) async {
        do {
            let loggedInUser = try await APIClient.shared.signInWithOAuth(provider: provider, idToken: idToken, displayName: displayName)
            user = loggedInUser
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signOut() async {
        try? await APIClient.shared.signOut()
        user = nil
    }
}
