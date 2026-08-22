import UIKit
import Photos

/// Fetches the latest photos from the user's library for the quick attach strip.
/// Mirrors the approach of Telegram's MediaPickerUI (PHFetchResult + caching manager),
/// scoped down to "N most recent images".
///
/// When access is denied or the library is empty, generated placeholder images are
/// returned so the gesture demo always works (e.g. on a fresh simulator).
final class RecentPhotosProvider {

    static let shared = RecentPhotosProvider()

    private let imageManager = PHCachingImageManager()
    private(set) var cachedThumbnails: [UIImage] = RecentPhotosProvider.placeholderImages(count: 4)
    private(set) var isShowingPlaceholders = true

    private init() {}

    /// Requests authorization (if needed) and refreshes the thumbnail cache.
    func prefetch(count: Int = 4, itemSide: CGFloat = 68) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            fetchThumbnails(count: count, itemSide: itemSide)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                guard newStatus == .authorized || newStatus == .limited else { return }
                DispatchQueue.main.async {
                    self?.fetchThumbnails(count: count, itemSide: itemSide)
                }
            }
        default:
            break // keep placeholders
        }
    }

    private func fetchThumbnails(count: Int, itemSide: CGFloat) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = count
        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        guard fetchResult.count > 0 else { return }

        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: itemSide * scale * 2.0, height: itemSide * scale * 2.0)
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .fast
        requestOptions.isNetworkAccessAllowed = true

        var results = [Int: UIImage]()
        let group = DispatchGroup()
        for index in 0..<fetchResult.count {
            let asset = fetchResult.object(at: index)
            group.enter()
            imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: requestOptions) { image, _ in
                if let image {
                    results[index] = image
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let ordered = (0..<fetchResult.count).compactMap { results[$0] }
            if !ordered.isEmpty {
                self.cachedThumbnails = ordered
                self.isShowingPlaceholders = false
            }
        }
    }

    // MARK: - Placeholders

    private static func placeholderImages(count: Int) -> [UIImage] {
        let palettes: [(UIColor, UIColor)] = [
            (UIColor(red: 0.99, green: 0.75, blue: 0.53, alpha: 1), UIColor(red: 0.95, green: 0.45, blue: 0.42, alpha: 1)),
            (UIColor(red: 0.55, green: 0.80, blue: 0.99, alpha: 1), UIColor(red: 0.30, green: 0.51, blue: 0.95, alpha: 1)),
            (UIColor(red: 0.72, green: 0.95, blue: 0.70, alpha: 1), UIColor(red: 0.28, green: 0.72, blue: 0.47, alpha: 1)),
            (UIColor(red: 0.93, green: 0.75, blue: 0.98, alpha: 1), UIColor(red: 0.66, green: 0.40, blue: 0.94, alpha: 1)),
        ]
        return (0..<count).map { index in
            let (top, bottom) = palettes[index % palettes.count]
            return gradientImage(size: CGSize(width: 300, height: 300), top: top, bottom: bottom, symbolName: ["photo", "mountain.2.fill", "camera.macro", "sun.max.fill"][index % 4])
        }
    }

    private static func gradientImage(size: CGSize, top: UIColor, bottom: UIColor, symbolName: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            let config = UIImage.SymbolConfiguration(pointSize: size.width * 0.28, weight: .medium)
            if let symbol = UIImage(systemName: symbolName, withConfiguration: config)?.withTintColor(UIColor(white: 1.0, alpha: 0.85), renderingMode: .alwaysOriginal) {
                let origin = CGPoint(x: (size.width - symbol.size.width) / 2, y: (size.height - symbol.size.height) / 2)
                symbol.draw(at: origin)
            }
        }
    }
}
