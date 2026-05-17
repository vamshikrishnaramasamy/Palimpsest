import SwiftUI
import AVKit

struct PostDetailView: View {
    let post: Post

    @State private var comments: [Comment] = []
    @State private var newCommentBody = ""
    @State private var isLoadingComments = true
    @State private var isSending = false
    @State private var isTogglingLike = false
    @State private var likeCount: Int
    @State private var commentCount: Int
    @State private var isLiked: Bool
    @State private var selectedAuthor: AuthorProfileSeed?
    @State private var showError = false
    @State private var errorMessage = ""

    init(post: Post) {
        self.post = post
        _likeCount = State(initialValue: post.like_count)
        _commentCount = State(initialValue: post.comment_count)
        _isLiked = State(initialValue: post.isLiked)
    }

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
        .sheet(item: $selectedAuthor) { author in
            AuthorProfileView(seed: author)
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
            Button {
                selectedAuthor = AuthorProfileSeed(post: post)
            } label: {
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
                    .padding(.top, 4)

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // Body
            if let metadata = detailLayerMetadata {
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
            }

            if !detailBodyText.isEmpty {
                Text(detailBodyText)
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let mediaURL = post.mediaURL {
                mediaView(url: mediaURL)
            }

            // Like & comment count
            HStack(spacing: 16) {
                Button {
                    Task { await toggleLike() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                        Text("\(likeCount)")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(isLiked ? Color(red: 0.937, green: 0.208, blue: 0.373) : .gray)
                }
                .buttonStyle(.plain)
                .disabled(isTogglingLike)

                HStack(spacing: 5) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 16))
                    Text("\(commentCount)")
                        .font(.system(size: 13))
                }
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

    private var detailLayerMetadata: DetailLayerMetadata? {
        DetailLayerMetadata.parse(post.body)
    }

    private var detailBodyText: String {
        detailLayerMetadata?.text ?? (post.body ?? "")
    }

    private func icon(for type: String) -> String {
        let lower = type.lowercased()
        if lower.contains("audio") { return "waveform" }
        if lower.contains("secret") { return "lock.fill" }
        if lower.contains("warning") { return "exclamationmark.triangle.fill" }
        if lower.contains("cross") { return "point.3.connected.trianglepath.dotted" }
        return "square.stack.3d.up.fill"
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
                commentCount = fetched.count
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
                commentCount = comments.count
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

    private func toggleLike() async {
        guard !isTogglingLike else { return }
        let wasLiked = isLiked

        await MainActor.run {
            isTogglingLike = true
            isLiked.toggle()
            likeCount += isLiked ? 1 : -1
        }

        do {
            let result = try await APIClient.shared.likePost(id: post.id)
            if let serverLiked = result["liked"] {
                await MainActor.run {
                    if serverLiked != isLiked {
                        likeCount += serverLiked ? 1 : -1
                    }
                    isLiked = serverLiked
                    likeCount = max(0, likeCount)
                    isTogglingLike = false
                }
            } else {
                await MainActor.run { isTogglingLike = false }
            }
        } catch {
            await MainActor.run {
                isLiked = wasLiked
                likeCount += wasLiked ? 1 : -1
                likeCount = max(0, likeCount)
                isTogglingLike = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

private struct DetailLayerMetadata {
    let type: String
    let place: String?
    let text: String

    static func parse(_ rawBody: String?) -> DetailLayerMetadata? {
        guard let rawBody else { return nil }
        let trimmed = rawBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["),
              let closing = trimmed.firstIndex(of: "]") else { return nil }

        let typeStart = trimmed.index(after: trimmed.startIndex)
        let rawType = String(trimmed[typeStart..<closing]).trimmingCharacters(in: .whitespacesAndNewlines)
        let remainingStart = trimmed.index(after: closing)
        let remaining = String(trimmed[remainingStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = remaining.split(separator: ":", maxSplits: 1).map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let place = parts.count == 2 && !parts[0].isEmpty ? parts[0] : nil
        let text = parts.count == 2 ? parts[1] : remaining
        return DetailLayerMetadata(type: prettify(rawType), place: place, text: text)
    }

    private static func prettify(_ type: String) -> String {
        type
            .replacingOccurrences(of: "Maya distinct overlap", with: "Crossing")
            .replacingOccurrences(of: "Maya overlap seed", with: "Crossing")
            .replacingOccurrences(of: "Overlap seed", with: "Crossing")
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
