import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = true
    @State private var isLoading = false

    private let surfaceInput = Color(red: 238/255, green: 238/255, blue: 238/255)
    private let borderColor = Color(red: 230/255, green: 230/255, blue: 230/255)
    private let mutedText = Color(red: 130/255, green: 130/255, blue: 130/255)

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            overlapLogo(width: 200, height: 160, textSize: 42)
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
                socialButton(title: "Continue with Google", systemImage: "g.circle")
                socialButton(title: "Continue with Apple", systemImage: "apple.logo")
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

    private func overlapLogo(width: CGFloat, height: CGFloat, textSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 176/255, green: 176/255, blue: 176/255).opacity(0.7))
                .frame(width: 140, height: 140)
                .offset(x: -20)

            Circle()
                .fill(Color(red: 217/255, green: 217/255, blue: 217/255).opacity(0.7))
                .frame(width: 140, height: 140)
                .offset(x: 20)

            Text("OverLap")
                .font(.system(size: textSize, weight: .bold, design: .default))
                .foregroundColor(.black)
        }
        .frame(width: width, height: height)
    }

    private func socialButton(title: String, systemImage: String) -> some View {
        Button(action: {}) {
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

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
