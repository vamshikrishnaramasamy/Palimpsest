import SwiftUI
import AVKit

struct PostCard: View {
    @Binding var post: Post
    @State private var isTogglingLike = false
    @State private var showPostDetail = false
    @State private var selectedAuthor: AuthorProfileSeed?

    private let likePink = Color(red: 0.937, green: 0.208, blue: 0.373)
    private let avatarGray = Color(red: 240/255, green: 240/255, blue: 240/255)
    private let timeGray = Color(red: 130/255, green: 130/255, blue: 130/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ---------- Header: Avatar + Name / Time ----------
            Button {
                selectedAuthor = AuthorProfileSeed(post: post)
            } label: {
                HStack(alignment: .center, spacing: 10) {
                // Avatar circle with initial
                    ZStack {
                        if let avatarURL = post.avatarURL {
                            AsyncImage(url: avatarURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())
                                default:
                                    Circle()
                                        .fill(avatarGray)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text(post.displayName.prefix(1).uppercased())
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.black)
                                        )
                                }
                            }
                        } else {
                            Circle()
                                .fill(avatarGray)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(post.displayName.prefix(1).uppercased())
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.black)
                                    )
                        }
                    }

                    // Name + Time
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.displayName)
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(.black)
                            .lineLimit(1)

                        Text(post.relativeTime)
                            .font(.system(size: 12, design: .default))
                            .foregroundColor(timeGray)
                    }
                    .padding(.top, 4)

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // ---------- Body text ----------
            if let metadata = layerMetadata {
                HStack(spacing: 8) {
                    Label(metadata.type, systemImage: icon(for: metadata.type))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.08))
                        .clipShape(Capsule())

                    if let place = metadata.place {
                        Text(place)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            if !displayBody.isEmpty {
                Text(displayBody)
                    .font(.system(size: 15, design: .default))
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.top, layerMetadata == nil ? 10 : 7)
            }

            if let mediaURL = post.mediaURL {
                mediaPreview(url: mediaURL)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            // ---------- Action row ----------
            HStack(spacing: 16) {
                // Heart / Like
                Button(action: toggleLike) {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(post.isLiked ? likePink : .black)

                        Text("\(post.like_count)")
                            .font(.system(size: 13, design: .default))
                            .foregroundColor(.black)
                    }
                }
                .disabled(isTogglingLike)

                // Comment
                Button {
                    showPostDetail = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                        Text("\(post.comment_count)")
                            .font(.system(size: 13, design: .default))
                            .foregroundColor(.black)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.035), radius: 8, y: 3)
        .background(
            NavigationLink(isActive: $showPostDetail) {
                PostDetailView(post: post)
            } label: {
                EmptyView()
            }
            .hidden()
        )
        .sheet(item: $selectedAuthor) { author in
            AuthorProfileView(seed: author)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: - Like Toggle

    @ViewBuilder
    private func mediaPreview(url: URL) -> some View {
        switch post.mediaKind {
        case .image:
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(4)
                        .frame(maxWidth: .infinity)
                        .clipped()
                case .failure:
                    mediaFallback(icon: "photo", title: "Image unavailable")
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.05))
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .cornerRadius(4)
                        .overlay(ProgressView())
                @unknown default:
                    EmptyView()
                }
            }
        case .audio:
            FeedAudioPreview(url: url)
        case .video:
            mediaFallback(icon: "play.rectangle.fill", title: "Video layer")
        case .unknown:
            mediaFallback(icon: "paperclip", title: "Attachment")
        }
    }

    private func mediaFallback(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
            Spacer()
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var displayBody: String {
        layerMetadata?.text ?? (post.body ?? "")
    }

    private var layerMetadata: LayerMetadata? {
        LayerMetadata.parse(post.body)
    }

    private func icon(for type: String) -> String {
        let lower = type.lowercased()
        if lower.contains("audio") { return "waveform" }
        if lower.contains("secret") { return "lock.fill" }
        if lower.contains("warning") { return "exclamationmark.triangle.fill" }
        if lower.contains("distinct") || lower.contains("cross") || lower.contains("overlap") { return "point.3.connected.trianglepath.dotted" }
        if lower.contains("seed") { return "mappin.and.ellipse" }
        return "square.stack.3d.up.fill"
    }

    private func toggleLike() {
        guard !isTogglingLike else { return }
        isTogglingLike = true

        let wasLiked = post.isLiked

        // Optimistic update
        withAnimation(.easeInOut(duration: 0.2)) {
            post.liked_by_me = wasLiked ? 0 : 1
            post.like_count += wasLiked ? -1 : 1
        }

        Task {
            do {
                let result = try await APIClient.shared.likePost(id: post.id)
                // Sync with server response if needed
                if let serverLiked = result["liked"] {
                    let serverValue = serverLiked ? 1 : 0
                    if serverValue != post.liked_by_me {
                        await MainActor.run {
                            post.liked_by_me = serverValue
                        }
                    }
                }
            } catch {
                // Revert on failure
                await MainActor.run {
                    post.liked_by_me = wasLiked ? 1 : 0
                    post.like_count += wasLiked ? 1 : -1
                }
            }
            isTogglingLike = false
        }
    }
}

struct AuthorProfileSeed: Identifiable {
    let id: String
    let name: String
    let email: String?
    let avatarURL: URL?

    init(post: Post) {
        id = post.user_id
        name = post.displayName
        email = post.email
        avatarURL = post.avatarURL
    }
}

struct AuthorProfileView: View {
    let seed: AuthorProfileSeed

    @Environment(\.dismiss) private var dismiss
    @State private var profile: PublicProfile?
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var followersCount = 0
    @State private var isTogglingFollow = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                avatar

                VStack(spacing: 5) {
                    Text(profile?.displayName ?? seed.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.black)
                    if let email = profile?.email ?? seed.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }

                HStack(spacing: 34) {
                    StatItem(value: profile?.posts_count ?? 0, label: "Posts")
                    StatItem(value: followersCount, label: "Followers")
                    StatItem(value: profile?.following_count ?? 0, label: "Following")
                }
                .padding(.vertical, 6)

                if profile?.is_me == true {
                    Text("This is your profile")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .padding(.vertical, 12)
                } else {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isFollowing ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(isFollowing ? Color(red: 0.94, green: 0.94, blue: 0.94) : Color.black)
                            .clipShape(Capsule())
                    }
                    .disabled(isLoading || isTogglingFollow)
                    .padding(.horizontal, 26)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 30)
            .background(Color.white)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.black)
                }
            }
            .task { await loadProfile() }
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = profileAvatarURL ?? seed.avatarURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(red: 0.94, green: 0.94, blue: 0.94))
            .frame(width: 88, height: 88)
            .overlay(
                Text(String((profile?.displayName ?? seed.name).prefix(1)).uppercased())
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)
            )
    }

    private var profileAvatarURL: URL? { profile?.avatarURL }

    private func loadProfile() async {
        isLoading = true
        do {
            let fetched = try await APIClient.shared.getUserProfile(id: seed.id)
            await MainActor.run {
                profile = fetched
                isFollowing = fetched.followed_by_me
                followersCount = fetched.followers_count
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func toggleFollow() async {
        guard !isTogglingFollow else { return }
        await MainActor.run { isTogglingFollow = true }

        do {
            let response = try await APIClient.shared.toggleFollow(userId: seed.id)
            await MainActor.run {
                isFollowing = response.following
                followersCount = response.followers_count
                isTogglingFollow = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isTogglingFollow = false
            }
        }
    }
}

private struct LayerMetadata {
    let type: String
    let place: String?
    let text: String

    static func parse(_ rawBody: String?) -> LayerMetadata? {
        guard let rawBody else { return nil }
        let trimmed = rawBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["),
              let closing = trimmed.firstIndex(of: "]") else { return nil }

        let typeStart = trimmed.index(after: trimmed.startIndex)
        let rawType = String(trimmed[typeStart..<closing]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawType.isEmpty else { return nil }

        let remainingStart = trimmed.index(after: closing)
        let remaining = String(trimmed[remainingStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = remaining.split(separator: ":", maxSplits: 1).map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let place = parts.count == 2 && !parts[0].isEmpty ? parts[0] : nil
        let text = parts.count == 2 ? parts[1] : remaining
        return LayerMetadata(type: prettify(rawType), place: place, text: text)
    }

    private static func prettify(_ type: String) -> String {
        type
            .replacingOccurrences(of: "Maya distinct overlap", with: "Crossing")
            .replacingOccurrences(of: "Maya overlap seed", with: "Crossing")
            .replacingOccurrences(of: "Overlap seed", with: "Crossing")
    }
}

private struct FeedAudioPreview: View {
    let url: URL

    @State private var player: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        Button {
            togglePlayback()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Audio layer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                    Text("Tap to \(isPlaying ? "pause" : "play")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "waveform")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .onDisappear {
            player?.pause()
            isPlaying = false
        }
    }

    private func togglePlayback() {
        if player == nil {
            player = AVPlayer(url: url)
        }

        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
}
