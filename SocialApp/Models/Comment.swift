import Foundation

struct Comment: Codable, Identifiable {
    let id: String
    let post_id: String
    let user_id: String
    let body: String
    let display_name: String?
    let email: String?
    let created_at: String

    var displayName: String { display_name ?? email?.components(separatedBy: "@").first ?? "Anonymous" }
    var initials: String { String(displayName.prefix(1)).uppercased() }
    var relativeTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: created_at) ?? ISO8601DateFormatter().date(from: created_at) else { return "" }
        let interval = Int(Date().timeIntervalSince(date))
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(interval / 60) min ago" }
        if interval < 86400 { return "\(interval / 3600) hrs ago" }
        return "\(interval / 86400) days ago"
    }
}

struct Profile: Codable {
    let id: String
    let email: String
    let display_name: String?
    let avatar_url: String?
    let posts_count: Int
    let followers_count: Int
    let following_count: Int

    var displayName: String { display_name ?? email.components(separatedBy: "@").first ?? "User" }
    var initials: String { String(displayName.prefix(1)).uppercased() }
}
