import Foundation

enum NetworkError: Error {
    case httpStatusCode(Int)
    case urlRequestError(Error)
    case urlSessionError
}

extension URLSession {

    /// Выполняет запрос и возвращает "сырые" данные ответа.
    /// Каждый вариант failure обрабатывается здесь же, до вызова комплишена на главном потоке.
    func data(
        for request: URLRequest,
        completion: @escaping (Result<Data, Error>) -> Void
    ) -> URLSessionTask {
        let fulfillCompletionOnMainThread: (Result<Data, Error>) -> Void = { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }

        let task = dataTask(with: request) { data, response, error in
            if let error {
                print("[dataTask]: NetworkError.urlRequestError - \(error.localizedDescription), url: \(request.url?.absoluteString ?? "-")")
                fulfillCompletionOnMainThread(.failure(NetworkError.urlRequestError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[dataTask]: NetworkError.urlSessionError - ответ не является HTTPURLResponse, url: \(request.url?.absoluteString ?? "-")")
                fulfillCompletionOnMainThread(.failure(NetworkError.urlSessionError))
                return
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                print("[dataTask]: NetworkError - код ошибки \(httpResponse.statusCode)")
                fulfillCompletionOnMainThread(.failure(NetworkError.httpStatusCode(httpResponse.statusCode)))
                return
            }

            guard let data else {
                print("[dataTask]: NetworkError.urlSessionError - тело ответа отсутствует")
                fulfillCompletionOnMainThread(.failure(NetworkError.urlSessionError))
                return
            }

            fulfillCompletionOnMainThread(.success(data))
        }

        return task
    }

    /// Выполняет запрос и декодирует ответ в объект типа T.
    /// Ошибки декодирования логируются вместе с данными, которые пытались декодировать.
    func objectTask<T: Decodable>(
        for request: URLRequest,
        completion: @escaping (Result<T, Error>) -> Void
    ) -> URLSessionTask {
        let decoder = JSONDecoder()

        return data(for: request) { result in
            switch result {
            case .success(let data):
                do {
                    let object = try decoder.decode(T.self, from: data)
                    completion(.success(object))
                } catch {
                    print("[objectTask]: DecodingError - \(error), данные: \(String(data: data, encoding: .utf8) ?? "-")")
                    completion(.failure(error))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
