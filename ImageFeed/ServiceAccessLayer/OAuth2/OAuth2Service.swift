import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum OAuth2ServiceError: Error {
    case invalidRequest
}

final class OAuth2Service {
    static let shared = OAuth2Service()

    private init() { }

    private let urlSession = URLSession.shared
    private let decoder = JSONDecoder()
    private let tokenEndpointURLString = "https://unsplash.com/oauth/token"

    func fetchAuthToken(_ code: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let request = makeOAuthTokenRequest(code: code) else {
            print("[OAuth2Service.fetchAuthToken]: OAuth2ServiceError.invalidRequest - не удалось собрать URLRequest для получения токена, code: \(code)")
            DispatchQueue.main.async {
                completion(.failure(OAuth2ServiceError.invalidRequest))
            }
            return
        }

        let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
            self?.handleTokenResponse(data: data, response: response, error: error, code: code, completion: completion)
        }

        task.resume()
    }

    private func handleTokenResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        code: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        if let error {
            print("[OAuth2Service.fetchAuthToken]: NetworkError - \(error.localizedDescription), code: \(code)")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            let error = URLError(.badServerResponse)
            print("[OAuth2Service.fetchAuthToken]: NetworkError - ответ сервера не является HTTPURLResponse, code: \(code)")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = URLError(.badServerResponse)
            print("[OAuth2Service.fetchAuthToken]: NetworkError - сервис Unsplash вернул код \(httpResponse.statusCode), code: \(code)")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }

        guard let data else {
            let error = URLError(.zeroByteResource)
            print("[OAuth2Service.fetchAuthToken]: NetworkError - тело ответа отсутствует, code: \(code)")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }

        do {
            let responseBody = try decoder.decode(OAuthTokenResponseBody.self, from: data)
            DispatchQueue.main.async {
                completion(.success(responseBody.accessToken))
            }
        } catch {
            print("[OAuth2Service.fetchAuthToken]: DecodingError - \(error.localizedDescription), code: \(code)")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
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
