/// The prototype deliberately ships a tiny local pack. It never asks for photo
/// or camera access, so the gesture remains deterministic on device and simulator.
enum StickerProvider {
    static let recentStickers: [StickerAsset] = [
        .image(name: "StickerCustom01"),
        .image(name: "StickerCustom02"),
        .video(resource: "XuanSol", fileExtension: "mp4"),
        .video(resource: "BomjaraMood", fileExtension: "mp4"),
    ]
}
