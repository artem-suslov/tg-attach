import AVFoundation
import UIKit

/// One reusable surface for a static asset or a silent, looping MP4 sticker.
final class StickerPreviewView: UIView {
    private let imageView = UIImageView()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?

    init(cornerRadius: CGFloat = 0, frame: CGRect = .zero) {
        super.init(frame: frame)
        setCornerRadius(cornerRadius)
        clipsToBounds = true
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        isUserInteractionEnabled = false
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func setCornerRadius(_ cornerRadius: CGFloat) {
        layer.cornerRadius = cornerRadius
        playerLayer?.cornerRadius = cornerRadius
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with asset: StickerAsset) {
        stopVideo()
        switch asset {
        case let .image(name):
            imageView.image = UIImage(named: name)
            imageView.isHidden = false
        case let .video(resource, fileExtension):
            imageView.image = nil
            imageView.isHidden = true
            guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension) else { return }
            let player = AVQueuePlayer()
            player.isMuted = true
            player.actionAtItemEnd = .none
            let item = AVPlayerItem(url: url)
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = .resizeAspect
            // The source MP4 has opaque green pixels in its outer corners.
            // Clip both layers so the chat wallpaper shows through instead.
            playerLayer.cornerRadius = layer.cornerRadius
            playerLayer.masksToBounds = true
            layer.insertSublayer(playerLayer, at: 0)
            self.player = player
            self.looper = AVPlayerLooper(player: player, templateItem: item)
            self.playerLayer = playerLayer
            player.play()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    deinit { stopVideo() }

    private func stopVideo() {
        player?.pause()
        looper?.disableLooping()
        playerLayer?.removeFromSuperlayer()
        player = nil
        looper = nil
        playerLayer = nil
    }
}
