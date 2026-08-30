import UIKit

enum StickerAsset {
    case image(name: String)
    case video(resource: String, fileExtension: String)

    var staticImage: UIImage? {
        guard case let .image(name) = self else { return nil }
        return UIImage(named: name)
    }
}
