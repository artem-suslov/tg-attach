import AVFoundation
import UIKit

/// One reusable surface for a static asset or a silent, looping MP4 sticker.
final class StickerPreviewView: UIView {
    private let imageView = UIImageView()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?
    private var playerClipMask: CAShapeLayer?
    private let contentClipMask = CAShapeLayer()
    private var frameLink: CADisplayLink?
    private var framePaths: [String] = []
    private var frameStart: CFTimeInterval = 0
    private var frameFPS: Double = 60
    private var currentFrame = -1

    init(cornerRadius: CGFloat = 0, frame: CGRect = .zero) {
        super.init(frame: frame)
        contentClipMask.fillColor = UIColor.black.cgColor
        layer.mask = contentClipMask
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
        updateContentClipMask()
        updatePlayerClipMask()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with asset: StickerAsset) {
        stopVideo()
        switch asset {
        case let .image(name):
            imageView.image = UIImage(named: name)
            imageView.isHidden = false
        case let .video(resource, fileExtension, _):
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
            // A reused table cell may already have completed its layout pass.
            // Give the new layer its current bounds immediately rather than
            // waiting for another layoutSubviews call.
            playerLayer.frame = bounds
            let clipMask = CAShapeLayer()
            clipMask.fillColor = UIColor.black.cgColor
            playerLayer.mask = clipMask
            layer.insertSublayer(playerLayer, at: 0)
            self.player = player
            self.looper = AVPlayerLooper(player: player, templateItem: item)
            self.playerLayer = playerLayer
            self.playerClipMask = clipMask
            updatePlayerClipMask()
            player.play()
        case let .frames(prefix, count, fps):
            // Frames are decoded one at a time on the display link instead of
            // being held in memory: 180 decoded 384px frames would be ~100 MB.
            imageView.isHidden = false
            framePaths = (0..<count).compactMap {
                Bundle.main.path(forResource: String(format: "%@_%03d", prefix, $0), ofType: "png")
            }
            frameFPS = fps
            currentFrame = -1
            showFrame(0)
            frameStart = CACurrentMediaTime()
            let link = CADisplayLink(target: DisplayLinkProxy(self), selector: #selector(DisplayLinkProxy.tick))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: Float(fps), preferred: Float(fps))
            link.isPaused = window == nil
            link.add(to: .main, forMode: .common)
            frameLink = link
        }
    }

    /// When the current frame-sequence loop started, so another view showing
    /// the same sticker can pick up the animation where this one is.
    var playbackStart: CFTimeInterval? {
        framePaths.isEmpty ? nil : frameStart
    }

    /// Continue the animation from another view's loop instead of frame 0 —
    /// used when a sticker flies from the quick fan into its chat message.
    func syncPlayback(to start: CFTimeInterval) {
        guard !framePaths.isEmpty else { return }
        frameStart = start
        advanceFrame()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        frameLink?.isPaused = window == nil
    }

    fileprivate func advanceFrame() {
        guard !framePaths.isEmpty else { return }
        let elapsed = CACurrentMediaTime() - frameStart
        showFrame(Int(elapsed * frameFPS) % framePaths.count)
    }

    private func showFrame(_ index: Int) {
        guard index != currentFrame, framePaths.indices.contains(index) else { return }
        currentFrame = index
        imageView.image = UIImage(contentsOfFile: framePaths[index])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
        updateContentClipMask()
        updatePlayerClipMask()
    }

    deinit { stopVideo() }

    private func stopVideo() {
        frameLink?.invalidate()
        frameLink = nil
        framePaths = []
        player?.pause()
        looper?.disableLooping()
        playerLayer?.removeFromSuperlayer()
        player = nil
        looper = nil
        playerLayer = nil
        playerClipMask = nil
    }

    private func updatePlayerClipMask() {
        guard let playerLayer, let playerClipMask else { return }
        let clipBounds = playerLayer.bounds
        playerClipMask.frame = clipBounds
        playerClipMask.path = UIBezierPath(
            roundedRect: clipBounds,
            cornerRadius: layer.cornerRadius
        ).cgPath
    }

    private func updateContentClipMask() {
        contentClipMask.frame = bounds
        contentClipMask.path = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: layer.cornerRadius
        ).cgPath
    }
}

/// CADisplayLink retains its target; the proxy keeps that from retaining the view.
private final class DisplayLinkProxy {
    weak var view: StickerPreviewView?
    init(_ view: StickerPreviewView) { self.view = view }
    @objc func tick() { view?.advanceFrame() }
}
