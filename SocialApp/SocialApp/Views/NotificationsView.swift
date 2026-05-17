import SwiftUI
import MapKit
import CoreLocation

struct NotificationsView: View {
    @State private var stories: [Post] = []
    @State private var isLoading = true
    @State private var selectedChip = "Stories"
    @State private var selectedStory: Post?
    @State private var showCreateLayer = false
    @StateObject private var locationProvider = MapLocationProvider()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 32.8801, longitude: -117.2340),
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
    )

    private let nearbyRadiusMeters = 100.0
    private let chips = ["Stories", "Secrets", "Overlap"]
    private var mappedStories: [Post] {
        nearbyStories.filter { $0.lat != nil && $0.lng != nil }
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

                    Text("Palimpsest turns physical places into stacks of memory. Overlap adds the invisible crossings between people.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }

                mapView

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
        .sheet(isPresented: $showCreateLayer) {
            CreatePostView {
                showCreateLayer = false
                Task { await loadStories() }
            }
        }
    }

    // MARK: - Real Map View

    private var mapView: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                UserAnnotation()

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
                                    .frame(width: 48, height: 48)
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                    .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 430)
            .clipShape(RoundedRectangle(cornerRadius: 30))

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

    private func distanceFromUser(to story: Post) -> Double? {
        guard let userLocation = locationProvider.location,
              let lat = story.lat,
              let lng = story.lng else { return nil }
        return CLLocation(latitude: lat, longitude: lng).distance(from: userLocation)
    }

    private func loadStories() async {
        isLoading = true
        do {
            let fetched = try await APIClient.shared.getPosts(limit: 200)
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
