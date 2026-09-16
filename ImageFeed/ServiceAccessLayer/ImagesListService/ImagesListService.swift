import Foundation
import CoreGraphics

// MARK: - Network models

struct UrlsResult: Decodable {
    let raw: String
    let full: String
    let regular: String
    let small: String
    let thumb: String
}

struct PhotoResult: Decodable {
    let id: String
    let createdAt: String?
    let width: Int
    let height: Int
    let likedByUser: Bool
    let description: String?
    let urls: UrlsResult

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case width
        case height
        case likedByUser = "liked_by_user"
        case description
        case urls
    }
}

struct PhotoLikeResult: Decodable {
    let photo: PhotoResult
}

// MARK: - UI model

struct Photo {
    let id: String
    let size: CGSize
    let createdAt: Date?
    let welcomeDescription: String?
    let thumbImageURL: String
    let largeImageURL: String
    let isLiked: Bool

    init(result: PhotoResult, dateFormatter: ISO8601DateFormatter) {
        self.id = result.id
        self.size = CGSize(width: CGFloat(result.width), height: CGFloat(result.height))
        // createdAt приходит опциональным и может не распарситься — обрабатываем оба случая.
        if let createdAt = result.createdAt {
            self.createdAt = dateFormatter.date(from: createdAt)
        } else {
            self.createdAt = nil
        }
        self.welcomeDescription = result.description
        self.thumbImageURL = result.urls.thumb
        self.largeImageURL = result.urls.full
        self.isLiked = result.likedByUser
    }

    /// Копия фото с изменённым состоянием лайка — используется для локального обновления после changeLike.
    init(photo: Photo, isLiked: Bool) {
        self.id = photo.id
        self.size = photo.size
        self.createdAt = photo.createdAt
        self.welcomeDescription = photo.welcomeDescription
        self.thumbImageURL = photo.thumbImageURL
        self.largeImageURL = photo.largeImageURL
        self.isLiked = isLiked
    }
}

// MARK: - Service

final class ImagesListService {
    static let shared = ImagesListService()
    private init() { }

    static let didChangeNotification = Notification.Name(rawValue: "ImagesListServiceDidChange")

    private(set) var photos: [Photo] = []

    private let urlSession = URLSession.shared
    private let perPage = 10

    /// Единственный экземпляр форматтера — создавать его на каждую фотографию дорого.
    private let isoDateFormatter = ISO8601DateFormatter()

    private var lastLoadedPage: Int?
    private var task: URLSessionTask?
    private var likeTask: URLSessionTask?

    /// Загружает очередную страницу. Номер страницы определяется внутри и не передаётся извне.
    /// Если загрузка уже идёт — новый запрос не создаётся.
    func fetchPhotosNextPage() {
        assert(Thread.isMainThread)

        guard task == nil else { return }

        let nextPage = (lastLoadedPage ?? 0) + 1

        guard let request = makePhotosRequest(page: nextPage) else {
            print("[ImagesListService.fetchPhotosNextPage]: URLRequestError - не удалось собрать запрос, page: \(nextPage)")
            return
        }

        let task = urlSession.objectTask(for: request) { [weak self] (result: Result<[PhotoResult], Error>) in
            guard let self else { return }

            switch result {
            case .success(let photoResults):
                let newPhotos = photoResults.map { Photo(result: $0, dateFormatter: self.isoDateFormatter) }

                // objectTask возвращает completion уже на главном потоке, но оставляем явный
                // переход, чтобы гарантировать обновление photos именно из главного потока.
                // task обнуляем здесь же: иначе между сбросом флага и обновлением lastLoadedPage
                // скролл успел бы запросить ту же самую страницу второй раз.
                DispatchQueue.main.async {
                    self.lastLoadedPage = nextPage
                    self.photos.append(contentsOf: newPhotos)
                    self.task = nil

                    NotificationCenter.default.post(
                        name: ImagesListService.didChangeNotification,
                        object: self
                    )
                }

            case .failure(let error):
                print("[ImagesListService.fetchPhotosNextPage]: NetworkError - \(error), page: \(nextPage)")
                DispatchQueue.main.async {
                    self.task = nil
                }
            }
        }

        self.task = task
        task.resume()
    }

    /// Ставит или снимает лайк. Гонка исключена: пока идёт запрос, новый не создаётся.
    func changeLike(photoId: String, isLike: Bool, _ completion: @escaping (Result<Void, Error>) -> Void) {
        assert(Thread.isMainThread)

        guard likeTask == nil else {
            print("[ImagesListService.changeLike]: duplicateRequest - предыдущий запрос лайка ещё выполняется, photoId: \(photoId)")
            return
        }

        guard let request = makeLikeRequest(photoId: photoId, isLike: isLike) else {
            print("[ImagesListService.changeLike]: URLRequestError - не удалось собрать запрос, photoId: \(photoId)")
            completion(.failure(URLError(.badURL)))
            return
        }

        let task = urlSession.objectTask(for: request) { [weak self] (result: Result<PhotoLikeResult, Error>) in
            guard let self else { return }
            self.likeTask = nil

            switch result {
            case .success(let likeResult):
                if let index = self.photos.firstIndex(where: { $0.id == photoId }) {
                    self.photos[index] = Photo(photo: self.photos[index], isLiked: likeResult.photo.likedByUser)
                }
                completion(.success(()))

            case .failure(let error):
                print("[ImagesListService.changeLike]: NetworkError - \(error), photoId: \(photoId), isLike: \(isLike)")
                completion(.failure(error))
            }
        }

        self.likeTask = task
        task.resume()
    }

    /// Сбрасывает состояние — пригодится при логауте.
    func cleanPhotos() {
        photos = []
        lastLoadedPage = nil
        task?.cancel()
        task = nil
    }

    // MARK: - Requests

    private func makePhotosRequest(page: Int) -> URLRequest? {
        guard
            let token = OAuth2TokenStorage.shared.token,
            var urlComponents = URLComponents(string: "https://api.unsplash.com/photos")
        else { return nil }

        urlComponents.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]

        guard let url = urlComponents.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func makeLikeRequest(photoId: String, isLike: Bool) -> URLRequest? {
        guard
            let token = OAuth2TokenStorage.shared.token,
            let url = URL(string: "https://api.unsplash.com/photos/\(photoId)/like")
        else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = isLike ? HTTPMethod.post.rawValue : HTTPMethod.delete.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
