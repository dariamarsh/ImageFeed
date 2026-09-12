import Foundation

struct Profile {
    let username: String
    let name: String
    let loginName: String
    let bio: String?
}

struct ProfileResult: Decodable {
    let username: String
    let firstName: String
    let lastName: String
    let bio: String?

    private enum CodingKeys: String, CodingKey {
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case bio
    }
}

final class ProfileService {
    static let shared = ProfileService()
    private init() { }

    private let urlSession = URLSession.shared
    private var task: URLSessionTask?

    private(set) var profile: Profile?

    /// GET /me — базовая информация о пользователе: username, имя и фамилия, короткая информация (bio).
    func fetchProfile(_ token: String, completion: @escaping (Result<Profile, Error>) -> Void) {
        assert(Thread.isMainThread)

        task?.cancel()

        guard let request = makeProfileRequest(token: token) else {
            print("[ProfileService.fetchProfile]: URLRequestError - не удалось собрать запрос")
            completion(.failure(URLError(.badURL)))
            return
        }

        let task = urlSession.objectTask(for: request) { [weak self] (result: Result<ProfileResult, Error>) in
            guard let self else { return }
            self.task = nil

            switch result {
            case .success(let result):
                let profile = Profile(
                    username: result.username,
                    name: "\(result.firstName) \(result.lastName)".trimmingCharacters(in: .whitespaces),
                    loginName: "@\(result.username)",
                    bio: result.bio
                )
                self.profile = profile
                completion(.success(profile))
            case .failure(let error):
                print("[ProfileService.fetchProfile]: NetworkError - \(error)")
                completion(.failure(error))
            }
        }

        self.task = task
        task.resume()
    }

    private func makeProfileRequest(token: String) -> URLRequest? {
        guard let url = URL(string: "https://api.unsplash.com/me") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
