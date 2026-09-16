import Foundation
import WebKit

final class ProfileLogoutService {
    static let shared = ProfileLogoutService()
    private init() { }

    /// Полный выход из аккаунта: удаляем токен, чистим куки и сбрасываем состояние сервисов.
    func logout() {
        cleanCookies()
        cleanToken()
        cleanServices()
    }

    private func cleanToken() {
        OAuth2TokenStorage.shared.token = nil
    }

    private func cleanCookies() {
        // Без очистки кук браузер не покажет поля логина и пароля при повторном входе.
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)

        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(
                    ofTypes: record.dataTypes,
                    for: [record],
                    completionHandler: { }
                )
            }
        }
    }

    private func cleanServices() {
        ImagesListService.shared.cleanPhotos()
        ProfileService.shared.cleanProfile()
        ProfileImageService.shared.cleanProfileImage()
    }
}
