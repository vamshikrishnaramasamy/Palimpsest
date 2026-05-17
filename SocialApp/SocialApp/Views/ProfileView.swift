import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var showEditProfile = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(Color(red: 99/255, green: 102/255, blue: 241/255))
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            avatarSection
                            nameSection
                            statsSection
                            editProfileButton
                            signOutButton
                        }
                        .padding(.vertical, 40)
                    }
                }
            }
            .background(Color.white)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(profile: $profile)
            }
            .task { await loadProfile() }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        Group {
            if let url = profile?.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    case .failure:
                        avatarPlaceholder
                    case .empty:
                        ProgressView()
                            .frame(width: 80, height: 80)
                    @unknown default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(red: 0.94, green: 0.94, blue: 0.94))
            .frame(width: 80, height: 80)
            .overlay(
                Text(profile?.initials ?? "U")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            )
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(spacing: 4) {
            Text(profile?.displayName ?? "User")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.black)

            Text(profile?.email ?? "")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 44) {
            StatItem(value: profile?.posts_count ?? 0, label: "Posts")
            StatItem(value: profile?.followers_count ?? 0, label: "Followers")
            StatItem(value: profile?.following_count ?? 0, label: "Following")
        }
        .padding(.vertical, 8)
    }

    // MARK: - Buttons

    private var editProfileButton: some View {
        Button {
            showEditProfile = true
        } label: {
            Text("Edit Profile")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(red: 99/255, green: 102/255, blue: 241/255))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 40)
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            Task { await authViewModel.signOut() }
        } label: {
            Text("Sign Out")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.red)
        }
        .padding(.top, 16)
    }

    // MARK: - Data Loading

    private func loadProfile() async {
        isLoading = true
        do {
            let fetched = try await APIClient.shared.getProfile()
            await MainActor.run {
                profile = fetched
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.black)

            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}
