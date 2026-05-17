import Foundation

enum SocialAuthConfig {
    static let googleClientID = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? ""
    static let googleRedirectScheme = Bundle.main.object(forInfoDictionaryKey: "GoogleRedirectScheme") as? String ?? ""

    static var googleRedirectURI: String {
        "\(googleRedirectScheme):/oauth2redirect/google"
    }
}
