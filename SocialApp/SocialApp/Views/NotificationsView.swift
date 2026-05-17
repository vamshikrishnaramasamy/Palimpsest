import SwiftUI
import MapKit
import CoreLocation

struct NotificationsView: View {
    @State private var stories: [Post] = []
    @State private var isLoading = true
    @State private var selectedChip = "Stories"
    @State private var selectedStory: Post?
    @State private var lockedTrace: Post?
    @State private var showCreateLayer = false
    @State private var showExpandedMap = false
    @StateObject private var locationProvider = MapLocationProvider()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 32.8801, longitude: -117.2340),
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
    )

    private let nearbyRadiusMeters = 100.0
    private let chips = ["Stories", "Secrets", "Crossings"]
    private var unlockedStories: [Post] {
        stories.filter { isUnlocked($0) }
    }
    private var followedTraces: [Post] {
        stories.filter { $0.is_following_author == true && $0.lat != nil && $0.lng != nil }
    }
    private var mappedStories: [Post] {
        let base = nearbyStories.filter { $0.lat != nil && $0.lng != nil }
        if selectedChip == "Crossings" {
            return base.filter { $0.is_following_author == true }
        }
        if selectedChip == "Secrets" {
            return base.filter { ($0.body ?? "").lowercased().contains("[secret]") }
        }
        return base
    }
    private var followedNearbyStories: [Post] {
        followedTraces.filter { isUnlocked($0) }
    }
    private var nearbyStories: [Post] {
        guard let userLocation = locationProvider.location else { return [] }

        return stories.filter { story in
            guard let lat = story.lat, let lng = story.lng else { return false }
            let storyLocation = CLLocation(latitude: lat, longitude: lng)
            return storyLocation.distance(from: userLocation) <= nearbyRadiusMeters
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Map")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .textCase(.uppercase)

                    Text("Layered stories around you")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.black)

                    Text("Palimpsest turns physical places into stacks of memory and reveals the invisible crossings between people.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }

                mapView
                mapLegend

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Nearby layers")
                            .font(.headline)
                            .foregroundColor(.black)
                        Spacer()
                        Button {
                            showCreateLayer = true
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                        }
                    }

                    if !followedTraces.isEmpty {
                        followedNearbySection
                    }

                    if isLoading {
                        ProgressView()
                            .tint(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                    } else if locationProvider.location == nil {
                        Text("Turn on location to reveal layers within 100 meters.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.vertical, 14)
                    } else if nearbyStories.isEmpty {
                        Text("No layers within 100 meters. Leave one here, or move closer to a saved place.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.vertical, 14)
                    } else {
                        ForEach(nearbyStories) { story in
                            Button {
                                selectedStory = story
                            } label: {
                                HStack(spacing: 12) {
                                    layerPlayIcon(for: story)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(story.body ?? "Untitled layer")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.black)
                                            .lineLimit(1)
                                        Text(layerSubtitle(for: story))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.gray.opacity(0.75))
                                }
                                .padding(12)
                                .background(Color(red: 0.94, green: 0.94, blue: 0.94))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(Color.white)
        .preferredColorScheme(.light)
        .onAppear {
            locationProvider.requestLocation()
            Task { await loadStories() }
        }
        .onReceive(locationProvider.$location) { location in
            guard let coordinate = location?.coordinate else { return }
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                )
            )
        }
        .sheet(item: $selectedStory) { story in
            NavigationStack {
                PostDetailView(post: story)
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Trace locked", isPresented: Binding(
            get: { lockedTrace != nil },
            set: { if !$0 { lockedTrace = nil } }
        )) {
            Button("OK") { lockedTrace = nil }
        } message: {
            Text("Move within 100 meters to unlock the layer from \(lockedTrace?.displayName ?? "this person").")
        }
        .sheet(isPresented: $showCreateLayer) {
            CreatePostView {
                showCreateLayer = false
                Task { await loadStories() }
            }
        }
        .fullScreenCover(isPresented: $showExpandedMap) {
            expandedMapView
        }
    }

    // MARK: - Real Map View

    private var mapView: some View {
        ZStack(alignment: .topTrailing) {
            mapCanvas(height: 430, cornerRadius: 30)

            Button {
                showExpandedMap = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.92))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .padding(14)
        }
    }

    private var expandedMapView: some View {
        ZStack(alignment: .top) {
            mapCanvas(height: nil, cornerRadius: 0)
                .ignoresSafeArea()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nearby map")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    Text("\(followedTraces.count) followed traces")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button {
                    showExpandedMap = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 38, height: 38)
                        .background(Color(red: 0.94, green: 0.94, blue: 0.94))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .preferredColorScheme(.light)
    }

    private var mapLegend: some View {
        HStack(spacing: 10) {
            legendItem(color: .red, label: "Unlocked layers")
            legendItem(color: .blue, label: "People you follow")
            legendItem(color: .gray, label: "Locked until 100m")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(red: 0.96, green: 0.96, blue: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.black.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mapCanvas(height: CGFloat?, cornerRadius: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                UserAnnotation()

                ForEach(followedTraces) { story in
                    Annotation("", coordinate: CLLocationCoordinate2D(latitude: story.lat!, longitude: story.lng!)) {
                        Button {
                            if isUnlocked(story) {
                                selectedStory = story
                            } else {
                                lockedTrace = story
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(isUnlocked(story) ? Color.blue.opacity(0.14) : Color.gray.opacity(0.12))
                                    .frame(width: isUnlocked(story) ? 74 : 58, height: isUnlocked(story) ? 74 : 58)
                                Circle()
                                    .fill(isUnlocked(story) ? Color.blue.opacity(0.22) : Color.gray.opacity(0.2))
                                    .frame(width: isUnlocked(story) ? 48 : 38, height: isUnlocked(story) ? 48 : 38)
                                Text(isUnlocked(story) ? initials(for: story) : "•")
                                    .font(.system(size: isUnlocked(story) ? 13 : 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(isUnlocked(story) ? Color.blue : Color.gray))
                                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                    .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Story pin annotations
                ForEach(mappedStories) { story in
                    Annotation("", coordinate: CLLocationCoordinate2D(
                        latitude: story.lat!,
                        longitude: story.lng!
                    )) {
                        Button {
                            selectedStory = story
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.2))
                                    .frame(width: 58, height: 58)
                                Text(initials(for: story))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill(Color.red))
                                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                    .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            if !isLoading && mappedStories.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 24, weight: .semibold))
                    Text(locationProvider.location == nil ? "Location needed" : "No layers within 100m")
                        .font(.system(size: 15, weight: .semibold))
                    Text(locationProvider.location == nil ? "Allow location to show only layers near you." : "Only layers within 100 meters appear on this map.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.black)
                .padding(18)
                .background(.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.bottom, 112)
            }

            // Bottom overlay card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Current layer")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(isLoading ? "Loading" : "\(mappedStories.count) within 100m")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                if !followedTraces.isEmpty {
                    Label("\(followedNearbyStories.count) unlocked · \(max(0, followedTraces.count - followedNearbyStories.count)) locked", systemImage: "person.2.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                HStack(spacing: 8) {
                    ForEach(chips, id: \.self) { chip in
                        layerChip(chip, selected: selectedChip == chip)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedChip = chip
                                }
                            }
                    }
                }
            }
            .padding()
            .background(.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding()
        }
    }

    private var followedNearbySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Followed traces")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                Spacer()
                Text("\(followedNearbyStories.count) unlocked")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            ForEach(followedTraces.prefix(4)) { story in
                Button {
                    if isUnlocked(story) {
                        selectedStory = story
                    } else {
                        lockedTrace = story
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isUnlocked(story) ? "person.fill" : "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(isUnlocked(story) ? Color.blue : Color.gray))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(story.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.black)
                            Text(isUnlocked(story) ? layerSubtitle(for: story) : lockedTraceSubtitle(for: story))
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(10)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func layerChip(_ title: String, selected: Bool) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(selected ? .white : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? Color.black : Color(red: 0.94, green: 0.94, blue: 0.94))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func layerPlayIcon(for story: Post) -> some View {
        ZStack {
            if let avatarURL = story.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Color.white
                    }
                }
            } else {
                Color.white
            }

            Circle()
                .fill(Color.white.opacity(0.84))
                .frame(width: 48, height: 48)

            Image(systemName: "play.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black)
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
    }

    private func layerSubtitle(for story: Post) -> String {
        var parts = [story.displayName]
        if let distance = distanceFromUser(to: story) {
            parts.append("\(Int(distance.rounded()))m away")
        }
        if !story.relativeTime.isEmpty {
            parts.append(story.relativeTime)
        }
        return parts.joined(separator: " · ")
    }

    private func initials(for story: Post) -> String {
        let words = story.displayName
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        let joined = words.joined()
        return joined.isEmpty ? "?" : joined
    }

    private func distanceFromUser(to story: Post) -> Double? {
        guard let userLocation = locationProvider.location,
              let lat = story.lat,
              let lng = story.lng else { return nil }
        return CLLocation(latitude: lat, longitude: lng).distance(from: userLocation)
    }

    private func isUnlocked(_ story: Post) -> Bool {
        guard story.is_following_author == true else {
            return distanceFromUser(to: story).map { $0 <= nearbyRadiusMeters } ?? false
        }
        return distanceFromUser(to: story).map { $0 <= nearbyRadiusMeters } ?? false
    }

    private func lockedTraceSubtitle(for story: Post) -> String {
        if let distance = distanceFromUser(to: story) {
            return "\(Int(distance.rounded()))m away · get within 100m to unlock"
        }
        return "Recent location · get within 100m to unlock"
    }

    private func loadStories() async {
        isLoading = true
        do {
            let fetched = try await APIClient.shared.getPosts(tab: "map", limit: 500)
            await MainActor.run {
                stories = fetched
                isLoading = false

                if let coordinate = locationProvider.location?.coordinate {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                        )
                    )
                } else if let first = fetched.first(where: { $0.lat != nil && $0.lng != nil }) {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: first.lat!, longitude: first.lng!),
                            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                        )
                    )
                }
            }
        } catch {
            await MainActor.run {
                stories = []
                isLoading = false
            }
        }
    }
}

@MainActor
private final class MapLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
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
