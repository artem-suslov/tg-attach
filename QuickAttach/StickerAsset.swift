import AVFoundation
import UIKit

enum StickerAsset {
    case image(name: String)
    case video(resource: String, fileExtension: String)

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
        case let .video(resource, fileExtension):
            guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension),
                  let track = AVURLAsset(url: url).tracks(withMediaType: .video).first else {
                return 1
            }
            let transformedSize = track.naturalSize.applying(track.preferredTransform)
            let width = abs(transformedSize.width)
            let height = abs(transformedSize.height)
            return height > 0 ? width / height : 1
        }
    }
}
