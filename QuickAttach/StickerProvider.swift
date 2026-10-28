/// The prototype deliberately ships a tiny local pack. It never asks for photo
/// or camera access, so the gesture remains deterministic on device and simulator.
enum StickerProvider {
    // Utya stickers from stickers/*.tgs, rendered frame by frame with rlottie
    // (Telegram's own Lottie renderer) at 384 px. Counts are op - ip, so the
    // loop does not repeat the frame it started on.
    static let recentStickers: [StickerAsset] = [
        .frames(prefix: "UtyaEating", count: 90, fps: 30),
        .frames(prefix: "UtyaGlass", count: 180, fps: 60),
        .frames(prefix: "UtyaRentgen", count: 180, fps: 60),
        .frames(prefix: "AnimatedSticker", count: 180, fps: 60),
    ]

    /// The rest of the pack: hidden during the quick fan, revealed to the right
    /// of the recent stickers once the strip is pinned and scrolled.
    static let moreStickers: [StickerAsset] = [
        .image(name: "StickerCustom01"),
        .image(name: "StickerCustom02"),
        .video(resource: "CryptoPackX", fileExtension: "mp4", aspectRatio: 1),
        .video(resource: "BomjaraMood", fileExtension: "mp4", aspectRatio: 1),
    ]

    /// Indices reported by the overlay address this list: recent first, then more.
    static var allStickers: [StickerAsset] { recentStickers + moreStickers }
}
