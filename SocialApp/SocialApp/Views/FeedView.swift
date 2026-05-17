import SwiftUI

struct FeedView: View {
    @State private var posts: [Post] = []
    @State private var selectedTab = "For you"
    @State private var isLoading = true
    @State private var hasAppeared = false

    private let tabs = ["Following", "For you", "Favorites"]

    private var apiTabParam: String {
        switch selectedTab {
        case "Following":  return "following"
        case "Favorites":  return "favorites"
        default:           return "for_you"
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
            } else if posts.isEmpty {
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
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        tabContextHeader
                        ForEach($posts) { $post in
                            PostCard(post: $post)
                        }
                    }
                }
                .refreshable {
                    await loadPosts()
                }
            }
        }
        .background(Color.white)
        .preferredColorScheme(.light)
        .task {
            guard !hasAppeared else { return }
            hasAppeared = true
            await loadPosts()
        }
    }

    // MARK: - Filter Tabs

    private var tabContextHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(activeTabStyle.tint.opacity(0.14))
                    .frame(width: 46, height: 46)
                Image(systemName: activeTabStyle.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(activeTabStyle.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(activeTabStyle.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                Text(activeTabStyle.subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(activeTabStyle.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

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
                    }
                    Task { await loadPosts() }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var emptySubtitle: String {
        switch selectedTab {
        case "Following":
            return "Follow people from Overlap and their layers will collect here."
        case "Favorites":
            return "Like layers with the heart button and they become your saved archive."
        default:
            return "Nearby and recent layers from the wider palimpsest appear here."
        }
    }

    private var activeTabStyle: FeedTabStyle {
        switch selectedTab {
        case "Following":
            return FeedTabStyle(
                title: "Following",
                subtitle: "Layers from people you chose to keep close.",
                icon: "person.2.fill",
                tint: Color(red: 0.11, green: 0.37, blue: 0.74),
                background: Color(red: 0.93, green: 0.96, blue: 1.0)
            )
        case "Favorites":
            return FeedTabStyle(
                title: "Favorites",
                subtitle: "Your saved layers, memories, and audio worth revisiting.",
                icon: "heart.fill",
                tint: Color(red: 0.86, green: 0.13, blue: 0.27),
                background: Color(red: 1.0, green: 0.94, blue: 0.96)
            )
        default:
            return FeedTabStyle(
                title: "For you",
                subtitle: "A mix of fresh, nearby, and high-signal location stories.",
                icon: "sparkles",
                tint: Color.black,
                background: Color(red: 0.95, green: 0.95, blue: 0.95)
            )
        }
    }

    // MARK: - Data Loading

    private func loadPosts() async {
        isLoading = true
        do {
            posts = try await APIClient.shared.getPosts(tab: apiTabParam)
        } catch {
            posts = []
        }
        isLoading = false
    }
}

private struct FeedTabStyle {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let background: Color
}

#Preview {
    FeedView()
}
