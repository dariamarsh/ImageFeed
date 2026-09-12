import Foundation

final class OAuth2TokenStorage {
    private let tokenKey = "OAuth2TokenStorage.authToken"
    private let userDefaults = UserDefaults.standard

    var token: String? {
        get {
            userDefaults.string(forKey: tokenKey)
        }
        set {
            guard let newValue else {
                userDefaults.removeObject(forKey: tokenKey)
                return
            }
            userDefaults.set(newValue, forKey: tokenKey)
        }
    }
}
