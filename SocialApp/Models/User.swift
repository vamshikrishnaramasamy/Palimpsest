import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let display_name: String?
    let avatar_url: String?

    var displayName: String { display_name ?? email.components(separatedBy: "@").first ?? "User" }
    var initials: String { String(displayName.prefix(1)).uppercased() }
}

struct AuthResponse: Codable {
    let user: User?
}
