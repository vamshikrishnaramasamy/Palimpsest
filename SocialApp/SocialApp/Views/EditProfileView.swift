import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var profile: Profile?

    @State private var displayName = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                avatarSection
                nameSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { toolbarContent }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                    await MainActor.run { selectedImageData = data }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(errorMessage)
            }
            .overlay { savingOverlay }
            .onAppear {
                displayName = profile?.displayName ?? ""
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Form Sections

    private var avatarSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    if let imageData = selectedImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(red: 0.94, green: 0.94, blue: 0.94))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(profile?.initials ?? "U")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                            )
                    }

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Text("Change Photo")
                            .font(.subheadline)
                            .foregroundColor(Color(red: 99/255, green: 102/255, blue: 241/255))
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.white)
        }
    }

    private var nameSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Display Name")
                    .font(.caption)
                    .foregroundColor(.gray)

                TextField("Enter your name", text: $displayName)
                    .font(.body)
                    .foregroundColor(.black)
                    .textFieldStyle(.plain)
                    .tint(Color(red: 99/255, green: 102/255, blue: 241/255))
            }
            .listRowBackground(Color.white)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
                .foregroundColor(.black)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                Task { await saveProfile() }
            } label: {
                Text("Save")
                    .fontWeight(.semibold)
                    .foregroundColor(isSaveDisabled
                        ? .gray
                        : Color(red: 99/255, green: 102/255, blue: 241/255))
            }
            .disabled(isSaveDisabled)
        }
    }

    // MARK: - Overlay

    @ViewBuilder
    private var savingOverlay: some View {
        if isSaving {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            ProgressView()
                .tint(Color(red: 99/255, green: 102/255, blue: 241/255))
                .scaleEffect(1.2)
        }
    }

    // MARK: - Helpers

    private var isSaveDisabled: Bool {
        displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving
    }

    private func saveProfile() async {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        await MainActor.run { isSaving = true }

        do {
            let updated = try await APIClient.shared.updateProfile(
                displayName: name,
                avatarData: selectedImageData
            )
            await MainActor.run {
                profile = updated
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
