import UIKit
import ProgressHUD

/// Синхронизирует показ/скрытие ProgressHUD с блокировкой UI, чтобы пользователь
/// не мог повторно открыть экран авторизации, пока идёт сетевой запрос.
final class UIBlockingProgressHUD {
    private static var window: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
    }

    static func show() {
        window?.isUserInteractionEnabled = false
        ProgressHUD.animate()
    }

    static func dismiss() {
        window?.isUserInteractionEnabled = true
        ProgressHUD.dismiss()
    }
}
