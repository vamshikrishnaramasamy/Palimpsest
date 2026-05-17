import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var showCreatePost = false

    var body: some View {
        TabView {
            NavigationStack {
                FeedView()
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(0)

            CreatePostView()
                .tabItem { Label("Create", systemImage: "plus.square.fill") }
                .tag(1)

            OverlapView()
                .tabItem { Label("Overlap", systemImage: "circle.circle") }
                .tag(2)

            NotificationsView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(3)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
                .tag(4)
        }
        .tint(.black)
        .preferredColorScheme(.light)
        .onAppear { configureTabBarAppearance() }
        .onChange(of: auth.isAuthenticated) { _, authenticated in
            if !authenticated {
                // User signed out - handled by App.swift
            }
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        appearance.shadowColor = UIColor.gray.withAlphaComponent(0.3)
        appearance.backgroundEffect = nil

        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]

        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.black
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.black]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

struct OverlapView: View {
    @State private var summary: OverlapSummary?
    @State private var isLoading = true
    @State private var selectedPersonID: String?
    @State private var pendingInvites = Set<String>()
    @State private var consentExplanation: String?

    private var people: [OverlapPerson] { summary?.people ?? [] }
    private var places: [OverlapPlace] { summary?.places ?? [] }
    private var selectedPerson: OverlapPerson? {
        people.first { $0.id == selectedPersonID } ?? people.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if isLoading {
                    ProgressView()
                        .tint(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else if people.isEmpty {
                    emptyState
                } else {
                    statsRow
                    peopleSection
                    selectedPersonPlaces
                    sharedPlacesSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 110)
        }
        .background(Color.white)
        .preferredColorScheme(.light)
        .onAppear { Task { await loadOverlap() } }
        .alert("Overlap consent", isPresented: Binding(
            get: { consentExplanation != nil },
            set: { if !$0 { consentExplanation = nil } }
        )) {
            Button("OK") { consentExplanation = nil }
        } message: {
            Text(consentExplanation ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overlap")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .textCase(.uppercase)

            Text("Path crossings")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)

            Text("Everyone who shared places with you, and the exact spots where your paths overlapped.")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(value: "\(summary?.totals?.people ?? people.count)", label: "people")
            statCard(value: "\(summary?.totals?.places ?? places.count)", label: "places")
            statCard(value: "\(summary?.totals?.crossings ?? people.reduce(0) { $0 + $1.crossings })", label: "crossings")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("People", detail: "Tap someone to see where")

            VStack(spacing: 10) {
                ForEach(people) { person in
                    Button {
                        selectedPersonID = person.id
                    } label: {
                        personRow(person, selected: selectedPerson?.id == person.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func personRow(_ person: OverlapPerson, selected: Bool) -> some View {
        let displayStatus = status(for: person)
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(selected ? Color.black : Color.white)
                    .frame(width: 46, height: 46)
                Text(String(person.name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(selected ? .white : .black)
            }
            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(person.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    statusPill(displayStatus, person: person)
                }

                Text(personSubtitle(person))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(person.crossings)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                Text("crossings")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(selected ? Color(red: 0.92, green: 0.92, blue: 0.92) : Color(red: 0.97, green: 0.97, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func statusPill(_ status: String, person: OverlapPerson) -> some View {
        if status == "invite" {
            Button {
                sendInvite(to: person)
            } label: {
                Text("invite")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        } else {
            Button {
                consentExplanation = status == "consented"
                    ? "Matched means both people agreed to compare historical paths. Exact shared places are visible."
                    : "Pending means an invite was sent. Exact shared places stay hidden until the other person accepts."
            } label: {
                Text(statusLabel(status))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(status == "consented" ? .white : .black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(status == "consented" ? Color.black : Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "consented": return "matched"
        case "pending": return "pending"
        default: return "invite"
        }
    }

    private var selectedPersonPlaces: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(selectedPerson.map { "Where with \($0.name)" } ?? "Shared places", detail: nil)

            if let selectedPerson, status(for: selectedPerson) != "consented" {
                lockedPlacesState(selectedPerson)
            } else if let places = selectedPerson?.places, !places.isEmpty {
                VStack(spacing: 8) {
                    ForEach(places) { place in
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Color(red: 0.94, green: 0.94, blue: 0.94)))
                            Text(place.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            Spacer()
                            Text("\(place.count)x")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                        }
                        .padding(10)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.black.opacity(0.08), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                }
            } else {
                Text("No place details yet")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    private func lockedPlacesState(_ person: OverlapPerson) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color(red: 0.94, green: 0.94, blue: 0.94)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(status(for: person) == "pending" ? "Invite pending" : "Invite to unlock exact places")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                    Text("Overlap only reveals locations after both people consent.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(12)
            .background(Color(red: 0.97, green: 0.97, blue: 0.97))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var sharedPlacesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Shared places", detail: "Most connected")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                    placeCard(place, rank: index + 1)
                }
            }
        }
    }

    private func placeCard(_ place: OverlapPlace, rank: Int) -> some View {
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 34, height: 34)
                    Image(systemName: placeIcon(for: place.name))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                Text("#\(rank)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(place.count) people crossed here")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { dot in
                    Capsule()
                        .fill(dot < densityLevel(for: place) ? Color.black : Color.black.opacity(0.12))
                        .frame(height: 5)
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .background(Color(red: 0.96, green: 0.96, blue: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func densityLevel(for place: OverlapPlace) -> Int {
        max(1, min(5, Int((place.strength * 5).rounded(.up))))
    }

    private func placeIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("bus") { return "bus.fill" }
        if lower.contains("coffee") { return "cup.and.saucer.fill" }
        if lower.contains("book") || lower.contains("library") { return "book.fill" }
        if lower.contains("bench") || lower.contains("patio") { return "figure.outdoor.cycle" }
        if lower.contains("hall") || lower.contains("stair") { return "building.2.fill" }
        if lower.contains("tree") || lower.contains("garden") { return "leaf.fill" }
        if lower.contains("crosswalk") { return "figure.walk" }
        return "mappin.and.ellipse"
    }
    private func sectionHeader(_ title: String, detail: String?) -> some View {
        return HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.black)
            Text("No overlaps yet")
                .font(.system(size: 20, weight: .bold))
            Text("Leave a few location layers, then compare with people who consent to path matching.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func status(for person: OverlapPerson) -> String {
        pendingInvites.contains(person.id) ? "pending" : person.status
    }

    private func personSubtitle(_ person: OverlapPerson) -> String {
        guard status(for: person) == "consented" else {
            return status(for: person) == "pending"
                ? "Waiting for consent to reveal exact places"
                : "Invite to reveal exact shared places"
        }
        return person.places?.prefix(2).map(\.name).joined(separator: " + ") ?? person.last
    }

    private func sendInvite(to person: OverlapPerson?) {
        guard let person else { return }
        selectedPersonID = person.id
        pendingInvites.insert(person.id)
        consentExplanation = "Invite sent to \(person.name). In the real app, they would approve before exact shared places become visible."
    }

    private func loadOverlap() async {
        isLoading = true
        do {
            let fetched = try await APIClient.shared.getOverlapSummary()
            await MainActor.run {
                summary = fetched
                selectedPersonID = fetched.people.first?.id
                isLoading = false
            }
        } catch {
            await MainActor.run {
                summary = nil
                selectedPersonID = nil
                isLoading = false
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
