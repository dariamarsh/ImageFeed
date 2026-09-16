import UIKit
import Kingfisher

final class ProfileViewController: UIViewController {

    // MARK: - Dependencies

    private let profileImageService = ProfileImageService.shared
    private var profileImageServiceObserver: NSObjectProtocol?

    // MARK: - UI Elements

    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "avatar"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 35
        return imageView
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Имя не указано"
        label.textColor = .white
        label.font = .systemFont(ofSize: 23, weight: .semibold)
        label.numberOfLines = 0
        return label
    }()

    private lazy var loginNameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "@неизвестный_пользователь"
        label.textColor = UIColor(red: 0.682, green: 0.686, blue: 0.706, alpha: 1)
        label.font = .systemFont(ofSize: 13)
        return label
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Профиль не заполнен"
        label.textColor = .white
        label.font = .systemFont(ofSize: 13)
        label.numberOfLines = 0
        return label
    }()

    private lazy var logoutButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "logout_button"), for: .normal)
        button.addTarget(self, action: #selector(didTapLogoutButton), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(red: 0.1019607843, green: 0.1058823529, blue: 0.1333333333, alpha: 1)

        addSubviews()
        activateConstraints()

        if let profile = ProfileService.shared.profile {
            updateProfileDetails(profile: profile)
        }

        profileImageServiceObserver = NotificationCenter.default.addObserver(
            forName: ProfileImageService.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAvatar()
        }

        updateAvatar()
    }

    // MARK: - Layout

    private func addSubviews() {
        [avatarImageView, nameLabel, loginNameLabel, descriptionLabel, logoutButton].forEach {
            view.addSubview($0)
        }
    }

    private func activateConstraints() {
        let safeArea = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 32),
            avatarImageView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            avatarImageView.widthAnchor.constraint(equalToConstant: 70),
            avatarImageView.heightAnchor.constraint(equalTo: avatarImageView.widthAnchor, multiplier: 1),

            logoutButton.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            logoutButton.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),
            logoutButton.widthAnchor.constraint(equalToConstant: 44),
            logoutButton.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),

            loginNameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            loginNameLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            loginNameLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: loginNameLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor)
        ])
    }

    // MARK: - Data

    private func updateProfileDetails(profile: Profile) {
        nameLabel.text = profile.name.isEmpty ? "Имя не указано" : profile.name
        loginNameLabel.text = profile.loginName
        descriptionLabel.text = (profile.bio?.isEmpty ?? true) ? "Профиль не заполнен" : profile.bio
    }

    private func updateAvatar() {
        guard
            let avatarURLString = profileImageService.avatarURL,
            let url = URL(string: avatarURLString)
        else { return }

        let processor = RoundCornerImageProcessor(cornerRadius: 35)
        avatarImageView.kf.indicatorType = .activity
        avatarImageView.kf.setImage(
            with: url,
            placeholder: UIImage(named: "avatar"),
            options: [
                .processor(processor),
                .scaleFactor(UIScreen.main.scale),
                .cacheOriginalImage
            ]
        ) { result in
            if case .failure(let error) = result {
                print("[ProfileViewController.updateAvatar]: NetworkError - \(error)")
            }
        }
    }

    // MARK: - Actions

    @objc
    private func didTapLogoutButton() {
        let alert = UIAlertController(
            title: "Пока, пока!",
            message: "Уверены, что хотите выйти?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Да", style: .default) { [weak self] _ in
            ProfileLogoutService.shared.logout()
            self?.switchToSplashViewController()
        })
        alert.addAction(UIAlertAction(title: "Нет", style: .default))

        present(alert, animated: true)
    }

    private func switchToSplashViewController() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first
        else {
            assertionFailure("Invalid window configuration")
            return
        }

        window.rootViewController = SplashViewController()
    }
}
