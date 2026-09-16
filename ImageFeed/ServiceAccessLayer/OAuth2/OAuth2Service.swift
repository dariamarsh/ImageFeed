import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum OAuth2ServiceError: Error {
    case invalidRequest
    case duplicateRequest
}

final class OAuth2Service {
    static let shared = OAuth2Service()

    private init() { }

    private let urlSession = URLSession.shared
    private let storage = OAuth2TokenStorage.shared
    private let tokenEndpointURLString = "https://unsplash.com/oauth/token"

    private var task: URLSessionTask?
    private var lastCode: String?

    /// Устойчив к состоянию гонки:
    /// 1) если fetchOAuthToken вызван дважды подряд с одинаковым code (второй вызов не дождался
    ///    завершения первого) — второй вызов отклоняется, пока первый ещё выполняется;
    /// 2) если fetchOAuthToken вызван сначала с одним code, а затем, пока первый запрос ещё не
    ///    завершился, — с другим code, предыдущий запрос отменяется и стартует новый.
    func fetchAuthToken(_ code: String, completion: @escaping (Result<String, Error>) -> Void) {
        assert(Thread.isMainThread)

        if task != nil {
            if lastCode == code {
                print("[OAuth2Service.fetchAuthToken]: OAuth2ServiceError.duplicateRequest - повторный вызов с тем же code, пока предыдущий запрос ещё выполняется, code: \(code)")
                completion(.failure(OAuth2ServiceError.duplicateRequest))
                return
            } else {
                task?.cancel()
            }
        }

        lastCode = code

        guard let request = makeOAuthTokenRequest(code: code) else {
            print("[OAuth2Service.fetchAuthToken]: OAuth2ServiceError.invalidRequest - не удалось собрать URLRequest, code: \(code)")
            task = nil
            lastCode = nil
            completion(.failure(OAuth2ServiceError.invalidRequest))
            return
        }

        let task = urlSession.objectTask(for: request) { [weak self] (result: Result<OAuthTokenResponseBody, Error>) in
            guard let self else { return }

            self.task = nil
            self.lastCode = nil

            switch result {
            case .success(let responseBody):
                self.storage.token = responseBody.accessToken
                completion(.success(responseBody.accessToken))
            case .failure(let error):
                print("[OAuth2Service.fetchAuthToken]: NetworkError - \(error), code: \(code)")
                completion(.failure(error))
            }
        }

        self.task = task
        task.resume()
    }

    // Совместимый алиас с исходным неймингом сервиса.
    func fetchOAuthToken(_ code: String, completion: @escaping (Result<String, Error>) -> Void) {
        fetchAuthToken(code, completion: completion)
    }

    private func makeOAuthTokenRequest(code: String) -> URLRequest? {
        guard var urlComponents = URLComponents(string: tokenEndpointURLString) else {
            print("[OAuth2Service.makeOAuthTokenRequest]: URLComponentsError - не удалось создать URLComponents из \(tokenEndpointURLString)")
            return nil
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: Constants.accessKey),
            URLQueryItem(name: "client_secret", value: Constants.secretKey),
            URLQueryItem(name: "redirect_uri", value: Constants.redirectURI),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "grant_type", value: "authorization_code")
        ]

        guard let url = urlComponents.url else {
            print("[OAuth2Service.makeOAuthTokenRequest]: URLError - не удалось получить URL из \(urlComponents), code: \(code)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        return request
    }
}
