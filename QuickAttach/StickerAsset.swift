import UIKit

enum StickerAsset {
    case image(name: String)
    case video(resource: String, fileExtension: String, aspectRatio: CGFloat)
    /// Transparent animation as a PNG sequence `<prefix>_000.png`…, e.g. a
    /// Telegram .tgs pre-rendered with rlottie.
    case frames(prefix: String, count: Int, fps: Double)

    var staticImage: UIImage? {
        guard case let .image(name) = self else { return nil }
        return UIImage(named: name)
    }

    /// The source aspect ratio is preserved in the chat rather than forcing
    /// every sticker into the old square message frame.
    var aspectRatio: CGFloat {
        switch self {
        case let .image(name):
            guard let image = UIImage(named: name), image.size.height > 0 else { return 1 }
            return image.size.width / image.size.height
        case let .video(_, _, aspectRatio):
            return aspectRatio
        case .frames:
            return 1
        }
    }

    /// Opaque photo / video stickers get rounded card corners; transparent
    /// Lottie stickers are drawn as-is so nothing of the artwork is clipped.
    var cornerRadius: CGFloat {
        switch self {
        case .image, .video: return 20
        case .frames: return 0
        }
    }
}
