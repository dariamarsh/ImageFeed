import Foundation

struct ProfileImage: Decodable {
    let small: String
    let medium: String
    let large: String
}

struct UserResult: Decodable {
    let profileImage: ProfileImage

    private enum CodingKeys: String, CodingKey {
        case profileImage = "profile_image"
    }
}

final class ProfileImageService {
    static let shared = ProfileImageService()
    private init() { }

    static let didChangeNotification = Notification.Name("ProfileImageProviderDidChange")

    private let urlSession = URLSession.shared
    private var task: URLSessionTask?

    private(set) var avatarURL: String?

    func fetchProfileImageURL(username: String, completion: @escaping (Result<String, Error>) -> Void) {
        assert(Thread.isMainThread)

        task?.cancel()

        guard let token = OAuth2TokenStorage.shared.token else {
            let error = URLError(.userAuthenticationRequired)
            print("[ProfileImageService.fetchProfileImageURL]: AuthError - токен авторизации отсутствует")
            completion(.failure(error))
            return
        }

        guard let request = makeProfileImageRequest(username: username, token: token) else {
            print("[ProfileImageService.fetchProfileImageURL]: URLRequestError - не удалось собрать запрос, username: \(username)")
            completion(.failure(URLError(.badURL)))
            return
        }

        let task = urlSession.objectTask(for: request) { [weak self] (result: Result<UserResult, Error>) in
            guard let self else { return }
            self.task = nil

            switch result {
            case .success(let userResult):
                let avatarURL = userResult.profileImage.small
                self.avatarURL = avatarURL
                completion(.success(avatarURL))

                NotificationCenter.default.post(
                    name: ProfileImageService.didChangeNotification,
                    object: self,
                    userInfo: ["URL": avatarURL]
                )

            case .failure(let error):
                print("[ProfileImageService.fetchProfileImageURL]: NetworkError - \(error), username: \(username)")
                completion(.failure(error))
            }
        }

        self.task = task
        task.resume()
    }

    func cleanProfileImage() {
        task?.cancel()
        task = nil
        avatarURL = nil
    }

    private func makeProfileImageRequest(username: String, token: String) -> URLRequest? {
        guard let url = URL(string: "https://api.unsplash.com/users/\(username)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}