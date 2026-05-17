import SwiftUI
import AuthenticationServices
import CryptoKit
import UIKit

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = true
    @State private var isLoading = false
    @State private var googleCoordinator = GoogleSignInCoordinator()

    private let surfaceInput = Color(red: 238/255, green: 238/255, blue: 238/255)
    private let borderColor = Color(red: 230/255, green: 230/255, blue: 230/255)
    private let mutedText = Color(red: 130/255, green: 130/255, blue: 130/255)

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            palimpsestLogo(width: 240, height: 160, textSize: 38)
                .padding(.bottom, 30)

            VStack(spacing: 6) {
                Text(isSignUp ? "Create an account" : "Welcome back")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.black)

                Text("Enter your email to \(isSignUp ? "sign up for" : "sign in to") this app")
                    .font(.system(size: 14, design: .default))
                    .foregroundColor(mutedText)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 24)

            // Email / Password fields
            VStack(spacing: 12) {
                TextField("email@domain.com", text: $email)
                    .font(.system(size: 14, design: .default))
                    .foregroundColor(.black)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: 1)
                    )

                SecureField("Password", text: $password)
                    .font(.system(size: 14, design: .default))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 32)

            // Error text
            if let error = auth.error {
                Text(error)
                    .font(.system(size: 12, design: .default))
                    .foregroundColor(.red)
                    .padding(.top, 12)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Sign in / Sign up button
            Button(action: handleAuth) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Continue")
                            .font(.system(size: 14, weight: .medium, design: .default))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .opacity(email.isEmpty || password.isEmpty || isLoading ? 0.55 : 1)
            .padding(.horizontal, 32)
            .padding(.top, 16)

            HStack(spacing: 10) {
                Rectangle()
                    .fill(borderColor)
                    .frame(height: 1)
                Text("or")
                    .font(.system(size: 14, design: .default))
                    .foregroundColor(mutedText)
                Rectangle()
                    .fill(borderColor)
                    .frame(height: 1)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)

            VStack(spacing: 8) {
                socialButton(title: "Continue with Google", systemImage: "g.circle", action: handleGoogleSignIn)
                    .disabled(isLoading)
            }
            .padding(.horizontal, 32)

            // Toggle sign in / sign up
            Button(action: { isSignUp.toggle() }) {
                HStack(spacing: 4) {
                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                        .foregroundColor(mutedText)
                    Text(isSignUp ? "Sign in" : "Sign up")
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                }
                .font(.system(size: 12, design: .default))
            }
            .padding(.top, 14)

            Spacer()
        }
        .background(Color.white)
        .preferredColorScheme(.light)
    }

    private func handleAuth() {
        guard !email.isEmpty, !password.isEmpty else { return }
        isLoading = true
        Task {
            if isSignUp {
                await auth.signUp(email: email, password: password)
            } else {
                await auth.signIn(email: email, password: password)
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func handleGoogleSignIn() {
        isLoading = true
        googleCoordinator.signIn { result in
            Task {
                switch result {
                case .success(let credential):
                    await auth.signInWithOAuth(provider: "google", idToken: credential.idToken, displayName: credential.displayName)
                case .failure(let error):
                    await MainActor.run { auth.error = error.localizedDescription }
                }
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func palimpsestLogo(width: CGFloat, height: CGFloat, textSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 176/255, green: 176/255, blue: 176/255).opacity(0.7))
                .frame(width: 140, height: 140)
                .offset(x: -20)

            Circle()
                .fill(Color(red: 217/255, green: 217/255, blue: 217/255).opacity(0.7))
                .frame(width: 140, height: 140)
                .offset(x: 20)

            Text("Palimpsest")
                .font(.system(size: textSize, weight: .bold, design: .default))
                .foregroundColor(.black)
        }
        .frame(width: width, height: height)
    }

    private func socialButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .default))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(surfaceInput)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct SocialCredential {
    let idToken: String
    let displayName: String?
}

private enum SocialSignInError: LocalizedError {
    case missingToken
    case googleNotConfigured
    case invalidCallback
    case invalidTokenResponse

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "The identity provider did not return a token."
        case .googleNotConfigured:
            return "Google sign-in needs your iOS OAuth client ID and reversed URL scheme in SocialAuthConfig.swift."
        case .invalidCallback:
            return "Google sign-in returned an invalid callback."
        case .invalidTokenResponse:
            return "Google sign-in returned an invalid token response."
        }
    }
}

private final class GoogleSignInCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var codeVerifier = ""

    func signIn(completion: @escaping (Result<SocialCredential, Error>) -> Void) {
        guard !SocialAuthConfig.googleClientID.isEmpty,
              !SocialAuthConfig.googleRedirectScheme.isEmpty else {
            completion(.failure(SocialSignInError.googleNotConfigured))
            return
        }

        codeVerifier = Self.randomURLSafeString(length: 64)
        let challenge = Self.codeChallenge(for: codeVerifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: SocialAuthConfig.googleClientID),
            URLQueryItem(name: "redirect_uri", value: SocialAuthConfig.googleRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account")
        ]

        guard let url = components.url else {
            completion(.failure(SocialSignInError.invalidCallback))
            return
        }

        let authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: SocialAuthConfig.googleRedirectScheme) { [weak self] callbackURL, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let self, let callbackURL else {
                completion(.failure(SocialSignInError.invalidCallback))
                return
            }
            Task {
                do {
                    let credential = try await self.exchangeCallback(callbackURL)
                    completion(.success(credential))
                } catch {
                    completion(.failure(error))
                }
            }
        }
        authSession.presentationContextProvider = self
        authSession.prefersEphemeralWebBrowserSession = true
        session = authSession
        authSession.start()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    private func exchangeCallback(_ callbackURL: URL) async throws -> SocialCredential {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw SocialSignInError.invalidCallback
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let fields = [
            "client_id": SocialAuthConfig.googleClientID,
            "redirect_uri": SocialAuthConfig.googleRedirectURI,
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": codeVerifier
        ]
        request.httpBody = fields
            .map { "\($0.key)=\(Self.formEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SocialSignInError.invalidTokenResponse
        }
        let token = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        guard let idToken = token.id_token else {
            throw SocialSignInError.missingToken
        }
        return SocialCredential(idToken: idToken, displayName: nil)
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func randomURLSafeString(length: Int) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in alphabet.randomElement() })
    }

    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private struct GoogleTokenResponse: Decodable {
    let id_token: String?
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
