import Foundation

struct APIErrorResponse: Codable {
    let error: String
}

struct OverlapPerson: Codable, Identifiable {
    let id: String
    let name: String
    let email: String?
    let status: String
    let crossings: Int
    let places: [OverlapPersonPlace]?
    let last: String
}

struct OverlapPersonPlace: Codable, Identifiable {
    let name: String
    let count: Int

    var id: String { name }
}

struct OverlapPlace: Codable, Identifiable {
    let name: String
    let count: Int
    let strength: Double

    var id: String { name }
}

struct OverlapTotals: Codable {
    let people: Int
    let places: Int
    let crossings: Int
}

struct OverlapSummary: Codable {
    let featured: OverlapPerson?
    let people: [OverlapPerson]
    let places: [OverlapPlace]
    let totals: OverlapTotals?
}

struct AuthResponseWithToken: Codable {
    let user: User?
    let token: String?
}

enum APIClientError: LocalizedError {
    case serverMessage(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .serverMessage(let message):
            return message
        case .invalidResponse:
            return "The server returned an invalid response."
        }
    }
}

class APIClient {
    static let shared = APIClient()
    private let baseURL = "http://64.181.233.156"
    private let session: URLSession

    // Persist JWT token
    private var authToken: String? {
        get { UserDefaults.standard.string(forKey: "authToken") }
        set { UserDefaults.standard.set(newValue, forKey: "authToken") }
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        session = URLSession(configuration: config)
    }

    // MARK: - Auth
    func signUp(email: String, password: String) async throws -> User {
        let body = ["email": email, "password": password]
        let data = try await post("/api/auth/signup", body: body)
        let response = try JSONDecoder().decode(AuthResponseWithToken.self, from: data)
        if let token = response.token {
            authToken = token
        }
        guard let user = response.user else { throw APIClientError.invalidResponse }
        return user
    }

    func signIn(email: String, password: String) async throws -> User {
        let body = ["email": email, "password": password]
        let data = try await post("/api/auth/signin", body: body)
        let response = try JSONDecoder().decode(AuthResponseWithToken.self, from: data)
        if let token = response.token {
            authToken = token
        }
        guard let user = response.user else { throw APIClientError.invalidResponse }
        return user
    }

    func signOut() async throws {
        _ = try await post("/api/auth/signout")
        authToken = nil
    }

    func getMe() async throws -> User? {
        let data = try await get("/api/auth/me")
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)
        return response.user
    }

    // MARK: - Posts
    func getPosts(tab: String = "for_you", limit: Int = 20) async throws -> [Post] {
        let data = try await get("/api/posts?tab=\(tab)&limit=\(limit)")
        return try JSONDecoder().decode([Post].self, from: data)
    }

    func createPost(
        body: String,
        imageData: Data?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        mediaFilename: String = "attachment.jpg",
        mediaContentType: String = "image/jpeg"
    ) async throws -> Post {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(baseURL)/api/posts")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)

        var bodyData = Data()
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"body\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append("\(body)\r\n".data(using: .utf8)!)

        if let longitude = longitude {
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"lng\"\r\n\r\n".data(using: .utf8)!)
            bodyData.append("\(longitude)\r\n".data(using: .utf8)!)
        }

        if let latitude = latitude {
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"lat\"\r\n\r\n".data(using: .utf8)!)
            bodyData.append("\(latitude)\r\n".data(using: .utf8)!)
        }

        if let imageData = imageData {
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"media_0\"; filename=\"\(mediaFilename)\"\r\n".data(using: .utf8)!)
            bodyData.append("Content-Type: \(mediaContentType)\r\n\r\n".data(using: .utf8)!)
            bodyData.append(imageData)
            bodyData.append("\r\n".data(using: .utf8)!)
        }
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = bodyData

        let data = try await send(request)
        return try JSONDecoder().decode(Post.self, from: data)
    }

    func likePost(id: String) async throws -> [String: Bool] {
        let data = try await post("/api/posts/\(id)/like")
        return try JSONDecoder().decode([String: Bool].self, from: data)
    }

    // MARK: - Comments
    func getComments(postId: String) async throws -> [Comment] {
        let data = try await get("/api/posts/\(postId)/comments")
        return try JSONDecoder().decode([Comment].self, from: data)
    }

    func addComment(postId: String, body: String) async throws -> Comment {
        let data = try await post("/api/posts/\(postId)/comments", body: ["body": body])
        return try JSONDecoder().decode(Comment.self, from: data)
    }

    // MARK: - Profile
    func getProfile() async throws -> Profile {
        let data = try await get("/api/profile")
        return try JSONDecoder().decode(Profile.self, from: data)
    }

    func updateProfile(displayName: String?, avatarData: Data?) async throws -> Profile {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(baseURL)/api/profile")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)

        var bodyData = Data()
        if let name = displayName {
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"display_name\"\r\n\r\n".data(using: .utf8)!)
            bodyData.append("\(name)\r\n".data(using: .utf8)!)
        }
        if let avatar = avatarData {
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
            bodyData.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            bodyData.append(avatar)
            bodyData.append("\r\n".data(using: .utf8)!)
        }
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = bodyData

        let data = try await send(request)
        return try JSONDecoder().decode(Profile.self, from: data)
    }

    // MARK: - Overlap
    func getOverlapSummary() async throws -> OverlapSummary {
        let data = try await get("/api/overlap")
        return try JSONDecoder().decode(OverlapSummary.self, from: data)
    }

    // MARK: - Private

    private func applyAuth(_ request: inout URLRequest) {
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func get(_ path: String) async throws -> Data {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        applyAuth(&request)
        return try await send(request)
    }

    private func post<T: Encodable>(_ path: String, body: T?) async throws -> Data {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return try await send(request)
    }

    private func post(_ path: String) async throws -> Data {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        return try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIClientError.serverMessage(errorResponse.error)
            }
            throw APIClientError.serverMessage("Request failed with status \(httpResponse.statusCode).")
        }

        return data
    }
}
