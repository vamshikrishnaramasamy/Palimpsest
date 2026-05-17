import Foundation

struct Post: Codable, Identifiable {
    let id: String
    let user_id: String
    let group_id: String?
    let body: String?
    let image_url: String?
    let lng: Double?
    let lat: Double?
    let display_name: String?
    let email: String?
    let avatar_url: String?
    let is_private: Bool?
    let is_following_author: Bool?
    var like_count: Int
    var comment_count: Int
    var liked_by_me: Int
    let created_at: String

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case group_id
        case body
        case image_url
        case lng
        case lat
        case display_name
        case email
        case avatar_url
        case is_private
        case is_following_author
        case like_count
        case comment_count
        case liked_by_me
        case created_at
    }

    init(
        id: String,
        user_id: String,
        group_id: String?,
        body: String?,
        image_url: String?,
        lng: Double?,
        lat: Double?,
        display_name: String?,
        email: String?,
        avatar_url: String?,
        is_private: Bool? = nil,
        is_following_author: Bool? = nil,
        like_count: Int,
        comment_count: Int,
        liked_by_me: Int,
        created_at: String
    ) {
        self.id = id
        self.user_id = user_id
        self.group_id = group_id
        self.body = body
        self.image_url = image_url
        self.lng = lng
        self.lat = lat
        self.display_name = display_name
        self.email = email
        self.avatar_url = avatar_url
        self.is_private = is_private
        self.is_following_author = is_following_author
        self.like_count = like_count
        self.comment_count = comment_count
        self.liked_by_me = liked_by_me
        self.created_at = created_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        user_id = try container.decode(String.self, forKey: .user_id)
        group_id = try container.decodeIfPresent(String.self, forKey: .group_id)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        image_url = try container.decodeIfPresent(String.self, forKey: .image_url)
        lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        display_name = try container.decodeIfPresent(String.self, forKey: .display_name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        avatar_url = try container.decodeIfPresent(String.self, forKey: .avatar_url)
        is_private = (try? container.decodeIfPresent(Bool.self, forKey: .is_private)) ?? ((try? container.decodeIfPresent(Int.self, forKey: .is_private)).map { $0 > 0 } ?? nil)
        is_following_author = (try? container.decodeIfPresent(Bool.self, forKey: .is_following_author)) ?? ((try? container.decodeIfPresent(Int.self, forKey: .is_following_author)).map { $0 > 0 } ?? nil)
        like_count = try container.decode(Int.self, forKey: .like_count)
        comment_count = try container.decode(Int.self, forKey: .comment_count)
        created_at = try container.decode(String.self, forKey: .created_at)

        if let likedInt = try? container.decode(Int.self, forKey: .liked_by_me) {
            liked_by_me = likedInt
        } else if let likedBool = try? container.decode(Bool.self, forKey: .liked_by_me) {
            liked_by_me = likedBool ? 1 : 0
        } else {
            liked_by_me = 0
        }
    }

    var displayName: String { display_name ?? email?.components(separatedBy: "@").first ?? "Anonymous" }
    var isLiked: Bool { liked_by_me > 0 }
    var avatarURL: URL? {
        guard let urlStr = avatar_url else { return nil }
        if urlStr.hasPrefix("http"), let url = URL(string: urlStr) { return url }
        if let url = URL(string: "http://64.181.233.156\(urlStr)") { return url }
        return nil
    }

    enum MediaKind {
        case image
        case video
        case audio
        case unknown
    }

    var mediaURL: URL? {
        guard let image_url else { return nil }
        if image_url.hasPrefix("http") {
            return URL(string: image_url)
        }
        return URL(string: "http://64.181.233.156\(image_url)")
    }

    var mediaKind: MediaKind {
        guard let ext = mediaURL?.pathExtension.lowercased() else { return .unknown }
        if ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(ext) { return .image }
        if ["mp4", "mov", "m4v", "webm"].contains(ext) { return .video }
        if ["mp3", "m4a", "aac", "wav", "caf", "ogg"].contains(ext) { return .audio }
        return .unknown
    }

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
