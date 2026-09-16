import UIKit
import Kingfisher

final class SingleImageViewController: UIViewController {

    var imageURL: URL?

    private var image: UIImage?

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.delegate = self

        loadFullSizeImage()
    }

    // MARK: - Loading

    private func loadFullSizeImage() {
        guard let imageURL else {
            print("[SingleImageViewController.loadFullSizeImage]: URLError - imageURL не задан")
            return
        }

        UIBlockingProgressHUD.show()

        imageView.kf.setImage(with: imageURL) { [weak self] result in
            UIBlockingProgressHUD.dismiss()
            guard let self else { return }

            switch result {
            case .success(let imageResult):
                self.image = imageResult.image
                self.showImage(imageResult.image)

            case .failure(let error):
                print("[SingleImageViewController.loadFullSizeImage]: KingfisherError - \(error), url: \(imageURL.absoluteString)")
                self.showLoadingErrorAlert()
            }
        }
    }

    private func showLoadingErrorAlert() {
        let alert = UIAlertController(
            title: "Что-то пошло не так(",
            message: "Попробовать ещё раз?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Не надо", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: "Повторить", style: .default) { [weak self] _ in
            self?.loadFullSizeImage()
        })
        present(alert, animated: true)
    }

    // MARK: - Actions

    @IBAction private func didTapBackButton() {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func didTapShareButton(_ sender: UIButton) {
        guard let image else { return }
        let share = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        present(share, animated: true, completion: nil)
    }

    // MARK: - Zoom

    private func showImage(_ image: UIImage) {
        view.layoutIfNeeded()

        imageView.image = image
        imageView.frame.size = image.size
        scrollView.contentSize = image.size

        let visibleRectSize = scrollView.bounds.size
        let imageSize = image.size

        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let hScale = visibleRectSize.width / imageSize.width
        let vScale = visibleRectSize.height / imageSize.height
        let fitScale = min(hScale, vScale)

        scrollView.minimumZoomScale = fitScale
        scrollView.maximumZoomScale = max(fitScale * 3, 1)

        scrollView.setZoomScale(fitScale, animated: false)
        scrollView.layoutIfNeeded()
        centerImageInScrollView()
    }

    private func centerImageInScrollView() {
        let visibleSize = scrollView.bounds.size
        let contentSize = scrollView.contentSize

        let horizontalInset = max(0, (visibleSize.width - contentSize.width) / 2)
        let verticalInset = max(0, (visibleSize.height - contentSize.height) / 2)

        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }
}

// MARK: - UIScrollViewDelegate

extension SingleImageViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageInScrollView()
    }
}