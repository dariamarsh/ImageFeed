import Foundation
import SwiftKeychainWrapper

final class OAuth2TokenStorage {
    static let shared = OAuth2TokenStorage()
    private init() { }

    private let tokenKey = "OAuth2TokenStorage.authToken"

    var token: String? {
        get {
            KeychainWrapper.standard.string(forKey: tokenKey)
        }
        set {
            guard let newValue else {
                KeychainWrapper.standard.removeObject(forKey: tokenKey)
                return
            }
            KeychainWrapper.standard.set(newValue, forKey: tokenKey)
        }
    }
}
