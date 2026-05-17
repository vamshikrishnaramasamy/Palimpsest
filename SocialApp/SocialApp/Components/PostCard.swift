import SwiftUI
import AVKit

struct PostCard: View {
    @Binding var post: Post
    @State private var isTogglingLike = false

    private let likePink = Color(red: 0.937, green: 0.208, blue: 0.373)
    private let avatarGray = Color(red: 240/255, green: 240/255, blue: 240/255)
    private let timeGray = Color(red: 130/255, green: 130/255, blue: 130/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ---------- Header: Avatar + Name / Time ----------
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // ---------- Body text ----------
            if let body = post.body, !body.isEmpty {
                Text(body)
                    .font(.system(size: 14, design: .default))
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
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
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                    Text("\(post.comment_count)")
                        .font(.system(size: 13, design: .default))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)

            // ---------- Divider ----------
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1 / UIScreen.main.scale)
        }
        .background(Color.white)
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
