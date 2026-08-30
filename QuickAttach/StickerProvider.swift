import UIKit

/// The prototype deliberately ships a tiny local pack. It never asks for photo
/// or camera access, so the gesture remains deterministic on device and simulator.
enum StickerProvider {
    static let recentStickers: [UIImage] = [
        "StickerCat", "StickerFlower", "StickerSun", "StickerTea", "StickerJelly", "StickerCloud",
    ].compactMap(UIImage.init(named:))
}
