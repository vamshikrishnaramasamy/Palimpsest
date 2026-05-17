import SwiftUI
import PhotosUI
import CoreLocation
import UniformTypeIdentifiers

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var postBody = ""
    @State private var placeName = "Where you are standing"
    @State private var selectedLayerType = "Memory"
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedMedia: LayerAttachment?
    @State private var showAudioImporter = false
    @State private var isPosting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @StateObject private var locationProvider = LayerLocationProvider()

    var onPostCreated: (() -> Void)?

    private let maxCharacterCount = 500
    private let layerTypes = ["Memory", "Secret", "Audio", "Warning"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    explainerCard
                    placeCard
                    layerTypeSection
                    mediaSection
                    storySection
                    helperText
                }
                .padding(20)
                .padding(.bottom, 96)
            }
            .safeAreaInset(edge: .bottom) {
                submitBar
            }
            .background(Color.white)
            .navigationTitle("Leave a Layer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { toolbarContent }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    guard let newItem,
                          let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                    let contentType = newItem.supportedContentTypes.first ?? .jpeg
                    await MainActor.run {
                        selectedMedia = LayerAttachment(
                            data: data,
                            filename: "layer-\(UUID().uuidString).\(contentType.preferredFilenameExtension ?? "jpg")",
                            contentType: contentType.preferredMIMEType ?? "application/octet-stream",
                            kind: contentType.conforms(to: .movie) ? .video : .image
                        )
                    }
                }
            }
            .fileImporter(isPresented: $showAudioImporter, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let shouldStop = url.startAccessingSecurityScopedResource()
                    defer {
                        if shouldStop { url.stopAccessingSecurityScopedResource() }
                    }
                    let data = try Data(contentsOf: url)
                    let contentType = UTType(filenameExtension: url.pathExtension) ?? .audio
                    selectedMedia = LayerAttachment(
                        data: data,
                        filename: url.lastPathComponent.isEmpty ? "layer-audio.m4a" : url.lastPathComponent,
                        contentType: contentType.preferredMIMEType ?? "audio/mpeg",
                        kind: .audio
                    )
                    selectedLayerType = "Audio"
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            .alert("Could not leave layer", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(errorMessage)
            }
            .overlay { postingOverlay }
            .onAppear {
                locationProvider.requestLocation()
            }
        }
        .preferredColorScheme(.light)
    }

    private var explainerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 48, height: 48)
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("What is a layer?")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                    Text("A layer is a story attached to a real place. Future visitors can unlock it when they stand near the same spot.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                explainerStep("1", "Pick place")
                explainerStep("2", "Leave story")
                explainerStep("3", "Others unlock it")
            }
        }
        .padding(18)
        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func explainerStep(_ number: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.black))
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(Capsule())
    }

    private var placeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Place")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black)
                        .frame(width: 54, height: 54)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Where are you?", text: $placeName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .textInputAutocapitalization(.words)
                    Text(locationProvider.locationStatusText)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var layerTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Layer type")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                ForEach(layerTypes, id: \.self) { type in
                    Button {
                        selectedLayerType = type
                    } label: {
                        Text(type)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(selectedLayerType == type ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(selectedLayerType == type ? Color.black : Color(red: 0.94, green: 0.94, blue: 0.94))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var storySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Story")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                Spacer()
                Text("\(postBody.count)/\(maxCharacterCount)")
                    .font(.caption)
                    .foregroundColor(postBody.count > maxCharacterCount ? .red : .gray)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.97, green: 0.97, blue: 0.97))

                if postBody.isEmpty {
                    Text(selectedLayerType == "Audio" ? "Add an optional caption for this audio layer." : "What happened here? What should someone feel when they unlock this place?")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .padding(16)
                }

                TextEditor(text: $postBody)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 180)
            }
        }
    }

    @ViewBuilder
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Attachment")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    clearAttachment()
                } label: {
                    Text(selectedMedia == nil ? "" : "Remove")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                }
                .disabled(selectedMedia == nil)
            }

            if let selectedMedia {
                ZStack(alignment: .topTrailing) {
                    attachmentPreview(selectedMedia)

                    Button {
                        clearAttachment()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.black.opacity(0.72)))
                    }
                    .padding(10)
                }
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    compactMediaButton(icon: "photo", title: "Image", isActive: selectedMedia?.kind == .image)
                }

                PhotosPicker(selection: $selectedItem, matching: .videos) {
                    compactMediaButton(icon: "video.fill", title: "Video", isActive: selectedMedia?.kind == .video)
                }

                Button {
                    showAudioImporter = true
                } label: {
                    compactMediaButton(icon: "waveform", title: "Audio", isActive: selectedMedia?.kind == .audio)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func compactMediaButton(icon: String, title: String, isActive: Bool) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(isActive ? .white : .black)
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background(isActive ? Color.black : Color(red: 0.94, green: 0.94, blue: 0.94))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func mediaOption(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.black)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(red: 0.97, green: 0.97, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func attachmentPreview(_ attachment: LayerAttachment) -> some View {
        switch attachment.kind {
        case .image:
            if let uiImage = UIImage(data: attachment.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .clipped()
            } else {
                mediaPreviewCard(icon: "photo", title: "Image attached", subtitle: attachment.filename)
            }
        case .video:
            mediaPreviewCard(icon: "video.fill", title: "Video attached", subtitle: attachment.filename)
        case .audio:
            mediaPreviewCard(icon: "waveform", title: "Audio attached", subtitle: attachment.filename)
        }
    }

    private func mediaPreviewCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.white))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(16)
        .frame(height: 112)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.97, green: 0.97, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var helperText: some View {
        Text("Layers are public demo memories. Keep it lightweight: one feeling, one place, one moment.")
            .font(.caption)
            .foregroundColor(.gray)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var submitBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.35)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedLayerType)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    Text(placeName.isEmpty ? "Unnamed place" : placeName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    Task { await createPost() }
                } label: {
                    Text(isPosting ? "Leaving..." : "Leave Layer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 46)
                        .background(isPostButtonDisabled ? Color.gray.opacity(0.55) : Color.black)
                        .clipShape(Capsule())
                }
                .disabled(isPostButtonDisabled)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.white)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
                .foregroundColor(.black)
        }
    }

    @ViewBuilder
    private var postingOverlay: some View {
        if isPosting {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
            ProgressView()
                .tint(.black)
                .scaleEffect(1.2)
        }
    }

    private var isPostButtonDisabled: Bool {
        !hasLayerContent ||
        postBody.count > maxCharacterCount ||
        isPosting
    }

    private var hasLayerContent: Bool {
        !postBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedMedia != nil
    }

    private func clearAttachment() {
        selectedItem = nil
        selectedMedia = nil
    }

    private func createPost() async {
        let body = postBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasLayerContent else { return }

        await MainActor.run { isPosting = true }

        let place = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let layerText = body.isEmpty ? defaultLayerBody : body
        let composedBody = "[\(selectedLayerType)] \(place.isEmpty ? "" : "\(place): ")\(layerText)"
        let coordinate = locationProvider.currentCoordinate

        do {
            _ = try await APIClient.shared.createPost(
                body: composedBody,
                imageData: selectedMedia?.data,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                mediaFilename: selectedMedia?.filename ?? "attachment.jpg",
                mediaContentType: selectedMedia?.contentType ?? "image/jpeg"
            )
            await MainActor.run {
                isPosting = false
                postBody = ""
                selectedMedia = nil
                selectedItem = nil
                onPostCreated?()
            }
        } catch {
            await MainActor.run {
                isPosting = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private var defaultLayerBody: String {
        switch selectedMedia?.kind {
        case .audio:
            return "Audio layer"
        case .video:
            return "Video layer"
        case .image:
            return "Image layer"
        case .none:
            return "Layer"
        }
    }
}

private struct LayerAttachment {
    enum Kind {
        case image
        case video
        case audio
    }

    let data: Data
    let filename: String
    let contentType: String
    let kind: Kind
}

@MainActor
private final class LayerLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private var coordinate: CLLocationCoordinate2D?
    @Published private var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let fallbackCoordinate = CLLocationCoordinate2D(latitude: 32.8801, longitude: -117.2340)

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    var currentCoordinate: CLLocationCoordinate2D {
        coordinate ?? fallbackCoordinate
    }

    var locationStatusText: String {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return coordinate == nil ? "Finding your current spot..." : "This layer will appear on the map at your current spot."
        case .denied, .restricted:
            return "Location is off, so this demo layer will appear near UCSD."
        default:
            return "Allow location so this layer appears exactly where you leave it."
        }
    }

    func requestLocation() {
        authorizationStatus = manager.authorizationStatus

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
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            coordinate = location.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            coordinate = fallbackCoordinate
        }
    }
}
