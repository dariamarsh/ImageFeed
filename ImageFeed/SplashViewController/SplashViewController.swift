import UIKit

final class SplashViewController: UIViewController {

    private let storage = OAuth2TokenStorage.shared
    private let profileService = ProfileService.shared

    private lazy var logoImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "splash_screen_logo"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(red: 0.1019607843, green: 0.1058823529, blue: 0.1333333333, alpha: 1)

        view.addSubview(logoImageView)
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private var hasCheckedAuthorization = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasCheckedAuthorization else { return }
        hasCheckedAuthorization = true

        if let token = storage.token {
            fetchProfile(token: token)
        } else {
            presentAuthViewController()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    private func presentAuthViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard
            let navigationController = storyboard.instantiateViewController(
                withIdentifier: "AuthNavigationController"
            ) as? UINavigationController,
            let authViewController = navigationController.viewControllers.first as? AuthViewController
        else {
            assertionFailure("Не удалось найти AuthNavigationController по идентификатору")
            return
        }
        authViewController.delegate = self
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }

    private func switchToTabBarController() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first
        else {
            assertionFailure("Invalid window configuration")
            return
        }

        let tabBarController = UIStoryboard(name: "Main", bundle: .main)
            .instantiateViewController(withIdentifier: "TabBarViewController")
        window.rootViewController = tabBarController
    }

    private func fetchProfile(token: String) {
        UIBlockingProgressHUD.show()

        profileService.fetchProfile(token) { [weak self] result in
            UIBlockingProgressHUD.dismiss()
            guard let self else { return }

            switch result {
            case .success(let profile):
                ProfileImageService.shared.fetchProfileImageURL(username: profile.username) { _ in }
                self.switchToTabBarController()
            case .failure(let error):
                print("[SplashViewController.fetchProfile]: NetworkError - \(error), token: \(token)")
                self.showProfileErrorAlert()
            }
        }
    }

    private func showProfileErrorAlert() {
        let alert = UIAlertController(
            title: "Что-то пошло не так(",
            message: "Не удалось загрузить профиль",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Ок", style: .default))
        present(alert, animated: true)
    }
}

extension SplashViewController: AuthViewControllerDelegate {
    func didAuthenticate(_ vc: AuthViewController) {
        vc.dismiss(animated: true) { [weak self] in
            guard let self, let token = self.storage.token else { return }
            self.fetchProfile(token: token)
        }
    }
}