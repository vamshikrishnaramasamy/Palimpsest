import SwiftUI
import AVKit

struct PostDetailView: View {
    let post: Post

    @State private var comments: [Comment] = []
    @State private var newCommentBody = ""
    @State private var isLoadingComments = true
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            scrollContent

            Divider()

            commentInputBar
        }
        .background(Color.white)
        .preferredColorScheme(.light)
        .navigationBarTitleDisplayMode(.inline)
        .task { await fetchComments() }
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                postSection
                commentsSection
            }
        }
    }

    // MARK: - Post Section

    private var postSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                avatarCircle(size: 40, initials: String(post.displayName.prefix(1)).uppercased())

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    Text(post.relativeTime)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()
            }

            // Body
            if let body = post.body, !body.isEmpty {
                Text(body)
                    .font(.body)
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let mediaURL = post.mediaURL {
                mediaView(url: mediaURL)
            }

            // Like & comment count
            HStack(spacing: 16) {
                Label("\(post.like_count)", systemImage: post.isLiked ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundColor(post.isLiked ? Color(red: 99/255, green: 102/255, blue: 241/255) : .gray)

                Label("\(post.comment_count)", systemImage: "bubble.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top, 4)
        }
        .padding()
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("Comments")
                    .font(.headline)
                    .foregroundColor(.black)
                Spacer()
                Text("\(comments.count)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Divider()
                .padding(.horizontal)

            if isLoadingComments {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
            } else if comments.isEmpty {
                emptyCommentsPlaceholder
            } else {
                commentList
            }
        }
    }

    private var emptyCommentsPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left")
                .font(.title)
                .foregroundColor(.gray)
            Text("No comments yet")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }

    private var commentList: some View {
        ForEach(comments) { comment in
            CommentRowView(comment: comment)
            Divider()
                .padding(.leading, 60)
        }
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        HStack(spacing: 10) {
            TextField("Add a comment...", text: $newCommentBody)
                .font(.body)
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.97, green: 0.97, blue: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .tint(Color(red: 99/255, green: 102/255, blue: 241/255))

            Button {
                Task { await sendComment() }
            } label: {
                if isSending {
                    ProgressView()
                        .tint(Color(red: 99/255, green: 102/255, blue: 241/255))
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend
                            ? Color(red: 99/255, green: 102/255, blue: 241/255)
                            : Color.gray.opacity(0.3))
                }
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
    }

    // MARK: - Helpers

    private var canSend: Bool {
        !newCommentBody.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
    }

    @ViewBuilder
    private func mediaView(url: URL) -> some View {
        switch post.mediaKind {
        case .image:
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure:
                    mediaFallback(icon: "photo", title: "Image could not load")
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                @unknown default:
                    EmptyView()
                }
            }
        case .video:
            VideoPlayer(player: AVPlayer(url: url))
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        case .audio:
            AudioLayerPlayer(url: url)
        case .unknown:
            Link(destination: url) {
                mediaFallback(icon: "paperclip", title: "Open attachment")
            }
        }
    }

    private func mediaFallback(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.black)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.black)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fetchComments() async {
        isLoadingComments = true
        do {
            let fetched = try await APIClient.shared.getComments(postId: post.id)
            await MainActor.run {
                comments = fetched
                isLoadingComments = false
            }
        } catch {
            await MainActor.run {
                isLoadingComments = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func sendComment() async {
        let body = newCommentBody.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return }

        await MainActor.run { isSending = true }

        do {
            let comment = try await APIClient.shared.addComment(postId: post.id, body: body)
            await MainActor.run {
                comments.append(comment)
                newCommentBody = ""
                isSending = false
            }
        } catch {
            await MainActor.run {
                isSending = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Comment Row

struct CommentRowView: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            avatarCircle(size: 32, initials: comment.initials)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(comment.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .lineLimit(1)

                    Text(comment.relativeTime)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Text(comment.body)
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

struct AudioLayerPlayer: View {
    let url: URL

    @State private var player: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 14) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.black))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Audio layer")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "waveform")
                .font(.title3)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

// MARK: - Shared Avatar Helper

func avatarCircle(size: CGFloat, initials: String) -> some View {
    Circle()
        .fill(Color(red: 0.94, green: 0.94, blue: 0.94))
        .frame(width: size, height: size)
        .overlay(
            Text(initials)
                .font(size <= 32 ? .caption : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)
        )
}
