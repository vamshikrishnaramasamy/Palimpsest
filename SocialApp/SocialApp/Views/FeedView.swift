import SwiftUI
import CoreLocation

struct FeedView: View {
    @State private var posts: [Post] = []
    @State private var selectedTab = "For you"
    @State private var selectedDiscoveryFilter: DiscoveryFilter = .recent
    @State private var selectedPost: Post?
    @State private var isLoading = true
    @State private var hasAppeared = false
    @State private var loadErrorMessage: String?
    @State private var lockedTrace: Post?
    @StateObject private var locationProvider = FeedLocationProvider()

    private let tabs = ["Following", "For you", "Favorites"]

    private var apiTabParam: String {
        switch selectedTab {
        case "Following":  return "following"
        case "Favorites":  return "favorites"
        default:           return "map"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ---------- Filter tabs ----------
            filterTabsView

            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1 / UIScreen.main.scale)

            // ---------- Content ----------
            if isLoading && posts.isEmpty {
                Spacer()
                ProgressView()
                    .tint(.black.opacity(0.4))
                Spacer()
            } else if isCurrentViewEmpty {
                Spacer()
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.08))
                            .frame(width: 72, height: 72)
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 28))
                            .foregroundColor(.black)
                    }
                    Text("No layers here yet")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    Text(emptySubtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 46)

                    if let loadErrorMessage {
                        Button {
                            Task { await loadPosts() }
                        } label: {
                            Text("Retry")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color.black)
                                .clipShape(Capsule())
                        }
                        Text(loadErrorMessage)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 46)
                    }
                }
                Spacer()
            } else {
                feedContent
            }
        }
        .background(Color.white)
        .preferredColorScheme(.light)
        .task {
            guard !hasAppeared else { return }
            hasAppeared = true
            locationProvider.requestLocation()
            await loadPosts()
        }
        .sheet(item: $selectedPost) { post in
            NavigationStack {
                PostDetailView(post: post)
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Trace locked", isPresented: Binding(
            get: { lockedTrace != nil },
            set: { if !$0 { lockedTrace = nil } }
        )) {
            Button("OK") { lockedTrace = nil }
        } message: {
            Text("Get within 100 meters to unlock this layer from \(lockedTrace?.displayName ?? "this person").")
        }
    }

    // MARK: - Filter Tabs

    private var filterTabsView: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                VStack(spacing: 6) {
                    Text(tab)
                        .font(.system(
                            size: 15,
                            weight: selectedTab == tab ? .semibold : .regular,
                            design: .default
                        ))
                        .foregroundColor(selectedTab == tab ? .black : .black.opacity(0.4))

                    Group {
                        if selectedTab == tab {
                            Capsule()
                                .fill(Color.black)
                                .frame(width: 24, height: 2)
                        } else {
                            Color.clear
                                .frame(height: 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                        if tab != "For you" {
                            selectedDiscoveryFilter = .recent
                        }
                        posts = []
                        isLoading = true
                    }
                    Task { await loadPosts() }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var feedContent: some View {
        switch selectedTab {
        case "Following":
            followingFeed
        case "Favorites":
            favoritesFeed
        default:
            forYouFeed
        }
    }

    private var forYouFeed: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                followedTracePreview
                discoveryStrip
                ForEach(filteredForYouIndices, id: \.self) { index in
                    PostCard(post: $posts[index])
                }
            }
            .padding(.bottom, 12)
        }
        .refreshable { await loadPosts() }
    }

    private var followingFeed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(followedAuthors, id: \.self) { author in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            avatarBadge(for: author, size: 34)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(author)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                                Text("\(postIndices(for: author).count) recent layers")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        VStack(spacing: 4) {
                            ForEach(postIndices(for: author), id: \.self) { index in
                                PostCard(post: $posts[index])
                            }
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .refreshable { await loadPosts() }
    }

    private var favoritesFeed: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                HStack {
                    Text("\(favoriteIndices.count) saved")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Most recent likes")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)

                ForEach(favoriteIndices, id: \.self) { index in
                    Button {
                        selectedPost = posts[index]
                    } label: {
                        savedLayerRow(post: posts[index])
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 16)
        }
        .refreshable { await loadPosts() }
    }

    private var discoveryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DiscoveryFilter.allCases) { filter in
                    discoveryChip(filter)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var followedTracePreview: some View {
        let traces = followedTraceIndices
        if !traces.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("People you follow")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                    Text("\(unlockedFollowedTraceCount) unlocked")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)

                ForEach(traces.prefix(4), id: \.self) { index in
                    traceRow(post: posts[index])
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 6)
        }
    }

    private func traceRow(post: Post) -> some View {
        let unlocked = isUnlocked(post)
        return Button {
            if unlocked {
                selectedPost = post
            } else {
                lockedTrace = post
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: unlocked ? "person.fill" : "lock.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(unlocked ? Color.blue : Color.gray))

                VStack(alignment: .leading, spacing: 3) {
                    Text(post.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    Text(unlocked ? traceUnlockedSubtitle(for: post) : lockedSubtitle(for: post))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: unlocked ? "chevron.right" : "location.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            }
            .padding(13)
            .background(unlocked ? Color.blue.opacity(0.08) : Color(red: 0.96, green: 0.96, blue: 0.96))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    private func discoveryChip(_ filter: DiscoveryFilter) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedDiscoveryFilter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(filter.title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(selectedDiscoveryFilter == filter ? .white : .black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedDiscoveryFilter == filter ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.95))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func savedLayerRow(post: Post) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.95))
                    .frame(width: 62, height: 62)
                Image(systemName: mediaIcon(for: post))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.black)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(cleanBody(post.body).text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let type = cleanBody(post.body).type {
                        Text(type)
                    }
                    Text(post.displayName)
                    Text("·")
                    Text(post.relativeTime)
                }
                .font(.caption)
                .foregroundColor(.gray)
            }

            Spacer()

            VStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.86, green: 0.13, blue: 0.27))
                Text("\(post.like_count)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
    }

    private func avatarBadge(for name: String, size: CGFloat) -> some View {
        Circle()
            .fill(Color.black)
            .frame(width: size, height: size)
            .overlay(
                Text(name.prefix(1).uppercased())
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private var emptySubtitle: String {
        switch selectedTab {
        case "Following":
            return "Follow people from Palimpsest and their layers will collect here."
        case "Favorites":
            return "Like layers with the heart button and they become your saved archive."
        default:
            return "Follow people to see recent location traces. Layers unlock when you are within 100 meters."
        }
    }

    private var followedAuthors: [String] {
        Array(Set(posts.map(\.displayName))).sorted()
    }

    private var followedTraceIndices: [Int] {
        posts.indices.filter { posts[$0].is_following_author == true && posts[$0].lat != nil && posts[$0].lng != nil }
    }

    private var unlockedFollowedTraceCount: Int {
        followedTraceIndices.filter { isUnlocked(posts[$0]) }.count
    }

    private func isUnlocked(_ post: Post) -> Bool {
        guard let userLocation = locationProvider.location,
              let lat = post.lat,
              let lng = post.lng else { return false }
        return CLLocation(latitude: lat, longitude: lng).distance(from: userLocation) <= 100
    }

    private func lockedSubtitle(for post: Post) -> String {
        guard let userLocation = locationProvider.location,
              let lat = post.lat,
              let lng = post.lng else {
            return "Recent location · get within 100m to unlock"
        }
        let distance = CLLocation(latitude: lat, longitude: lng).distance(from: userLocation)
        return "\(Int(distance.rounded()))m away · get within 100m to unlock"
    }

    private func traceUnlockedSubtitle(for post: Post) -> String {
        if let userLocation = locationProvider.location,
           let lat = post.lat,
           let lng = post.lng {
            let distance = CLLocation(latitude: lat, longitude: lng).distance(from: userLocation)
            return "\(Int(distance.rounded()))m away · tap to view layer"
        }
        return "Unlocked nearby · tap to view layer"
    }

    private var isCurrentViewEmpty: Bool {
        switch selectedTab {
        case "Favorites":
            return favoriteIndices.isEmpty
        case "For you":
            return filteredForYouIndices.isEmpty && followedTraceIndices.isEmpty
        default:
            return posts.isEmpty
        }
    }

    private var filteredForYouIndices: [Int] {
        switch selectedDiscoveryFilter {
        case .nearby:
            return posts.indices.filter { shouldShowPostCard(posts[$0]) && posts[$0].lat != nil && posts[$0].lng != nil }
        case .audio:
            return posts.indices.filter { shouldShowPostCard(posts[$0]) && posts[$0].mediaKind == .audio }
        case .photos:
            return posts.indices.filter { shouldShowPostCard(posts[$0]) && posts[$0].mediaKind == .image }
        case .recent:
            return posts.indices.filter { shouldShowPostCard(posts[$0]) }
        }
    }

    private func shouldShowPostCard(_ post: Post) -> Bool {
        if post.is_following_author == true, post.lat != nil, post.lng != nil {
            return isUnlocked(post)
        }
        return true
    }

    private var favoriteIndices: [Int] {
        posts.indices.filter { posts[$0].isLiked }
    }

    private func postIndices(for author: String) -> [Int] {
        posts.indices.filter { posts[$0].displayName == author }
    }

    private func mediaIcon(for post: Post) -> String {
        switch post.mediaKind {
        case .audio: return "play.fill"
        case .video: return "play.rectangle.fill"
        case .image: return "photo.fill"
        case .unknown: return post.lat == nil ? "text.alignleft" : "mappin.and.ellipse"
        }
    }

    private func cleanBody(_ body: String?) -> (type: String?, text: String) {
        let trimmed = (body ?? "Saved layer").trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["),
              let closing = trimmed.firstIndex(of: "]") else {
            return (nil, trimmed.isEmpty ? "Saved layer" : trimmed)
        }

        let typeStart = trimmed.index(after: trimmed.startIndex)
        let rawType = String(trimmed[typeStart..<closing]).trimmingCharacters(in: .whitespacesAndNewlines)
        let remainingStart = trimmed.index(after: closing)
        let remaining = String(trimmed[remainingStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (prettifiedType(rawType), remaining.isEmpty ? "Saved layer" : remaining)
    }

    private func prettifiedType(_ type: String) -> String {
        type
            .replacingOccurrences(of: "Maya distinct overlap", with: "Crossing")
            .replacingOccurrences(of: "Maya overlap seed", with: "Crossing")
            .replacingOccurrences(of: "Overlap seed", with: "Crossing")
    }

    // MARK: - Data Loading

    private func loadPosts() async {
        await MainActor.run { isLoading = true }
        do {
            let fetched = try await APIClient.shared.getPosts(tab: apiTabParam, limit: selectedTab == "For you" ? 200 : 50)
            await MainActor.run {
                posts = fetched
                loadErrorMessage = nil
                isLoading = false
            }
        } catch {
            await MainActor.run {
                if posts.isEmpty {
                    posts = []
                }
                loadErrorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

private enum DiscoveryFilter: String, CaseIterable, Identifiable {
    case nearby
    case audio
    case photos
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nearby: return "nearby"
        case .audio: return "audio"
        case .photos: return "photos"
        case .recent: return "recent"
        }
    }

    var icon: String {
        switch self {
        case .nearby: return "location.north.fill"
        case .audio: return "waveform"
        case .photos: return "photo.on.rectangle.angled"
        case .recent: return "clock.arrow.circlepath"
        }
    }
}

@MainActor
private final class FeedLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            location = latest
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
}

#Preview {
    FeedView()
}
