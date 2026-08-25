import UIKit
import AVFoundation
import CoreImage

/// Full-screen overlay implementing the ChatGPT-style quick attach gesture:
/// blurred background, a strip of recent photo thumbnails fanned out from the
/// attach button, finger tracking with scale highlight + haptics, and a
/// cancel "×" that morphs in place of the "+" button.
///
/// In the real Telegram-iOS integration plan this corresponds to the new
/// `QuickAttachmentUI` module driven by ContextGesture's
/// `externalUpdated` / `externalEnded` callbacks. Here the same roles are
/// played by `updateTracking(location:)` / `finishTracking(location:)`
/// driven from a UILongPressGestureRecognizer.
final class QuickAttachOverlayView: UIView {

    private let blurView = UIVisualEffectView(effect: nil)
    private let dimView = UIView()
    /// Stand-in for the composer's attach button, pixel-identical to it: the
    /// same glass circle stays in place and ONLY the icon morphs paperclip <-> ×.
    private let cancelButton = GlassSurfaceView(style: .regular, interactive: true)
    private let attachIconView = UIImageView()
    private let cancelIcon = UIImageView()

    private var itemViews: [UIImageView] = []
    private var itemFrames: [CGRect] = []
    private var sourceRect: CGRect = .zero
    private var highlightedIndex: Int?
    private var cancelHighlighted = false

    private let selectionHaptic = UISelectionFeedbackGenerator()
    private let impactHaptic = UIImpactFeedbackGenerator(style: .medium)

    private let itemSide: CGFloat = 68
    private let itemSpacing: CGFloat = 9
    private let stripBottomGap: CGFloat = 14
    private let hitSlop: CGFloat = 14

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurView)

        dimView.frame = bounds
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimView.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        dimView.alpha = 0.0
        addSubview(dimView)

        attachIconView.image = UIImage(named: "TGIconAttachment")
        attachIconView.tintColor = Theme.panelControl
        attachIconView.contentMode = .center
        cancelButton.contentView.addSubview(attachIconView)

        cancelIcon.image = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        cancelIcon.tintColor = Theme.panelControl
        cancelIcon.contentMode = .center
        cancelButton.contentView.addSubview(cancelIcon)
        addSubview(cancelButton)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Presentation

    /// - Parameter sourceRect: frame of the attach button in this view's coordinates (animation anchor).
    func present(images: [UIImage], from sourceRect: CGRect) {
        self.sourceRect = sourceRect
        impactHaptic.impactOccurred()
        selectionHaptic.prepare()

        // The glass circle takes the attach button's exact place (the real button
        // hides underneath) and only the ICON morphs paperclip -> ×.
        cancelButton.frame = sourceRect
        attachIconView.frame = cancelButton.bounds
        cancelIcon.frame = cancelButton.bounds
        cancelButton.alpha = 1.0
        cancelButton.transform = .identity
        attachIconView.alpha = 1.0
        attachIconView.transform = .identity
        cancelIcon.alpha = 0.0
        cancelIcon.transform = CGAffineTransform(rotationAngle: -.pi / 2).scaledBy(x: 0.5, y: 0.5)

        // Layout the strip above the source button, left-aligned to it.
        itemFrames = []
        let count = images.count + 1 // + the leading camera item
        let stripY = sourceRect.minY - stripBottomGap - itemSide
        var x = sourceRect.minX
        let maxX = bounds.width - 8 - itemSide
        for _ in 0..<count {
            itemFrames.append(CGRect(x: min(x, maxX), y: stripY, width: itemSide, height: itemSide))
            x += itemSide + itemSpacing
        }

        // Item 0 is always the live camera tile (ChatGPT reference), then photos.
        let cameraItem = CameraStripItemView()
        var views: [UIImageView] = [cameraItem]
        views.append(contentsOf: images.map { UIImageView(image: $0) })
        for view in views {
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
            view.layer.cornerRadius = 14
            view.layer.cornerCurve = .continuous
            addSubview(view)
        }
        itemViews = views

        // Start state: all cards spawn STRICTLY at the paperclip icon center,
        // rounded almost into a circle, slightly blurred; leftmost on top.
        // Travel runs on TWO SEPARATE axis springs (see FanTuning): a fast
        // vertical spring with overshoot + a slower horizontal one bend the
        // path into a natural arc while keeping true spring physics.
        for (index, view) in itemViews.enumerated() {
            view.frame = itemFrames[index]
            view.alpha = 0.0 // fades in over 0.15s with the card's launch
            view.layer.cornerRadius = 34.0

            if !(view is CameraStripItemView), let image = view.image,
               let blurred = Self.blurredImage(image, radius: 10) {
                let veil = UIImageView(image: blurred)
                veil.contentMode = .scaleAspectFill
                veil.clipsToBounds = true
                veil.frame = view.bounds
                veil.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                veil.tag = 777
                view.addSubview(veil)
            }
        }
        for view in itemViews.reversed() {
            bringSubviewToFront(view)
        }
        bringSubviewToFront(cancelButton)

        // Blur ramps in fast (~120ms in the reference).
        UIView.animate(withDuration: 0.12) {
            self.blurView.effect = UIBlurEffect(style: .systemUltraThinMaterialLight)
            self.dimView.alpha = 1.0
        }
        // Icon-only morph paperclip -> × (the circle itself never moves).
        // Driven by explicit CA animations with an explicit fromValue: the ×
        // birth state is set in this same runloop turn on a freshly created
        // layer, so a UIView animation would read the final value as its
        // "from" and pop the icon to full size in one frame.
        Self.morphIcon(attachIconView, fromScale: 1.0, toScale: 0.5,
                       fromRotation: 0.0, toRotation: .pi / 2,
                       fromAlpha: 1.0, toAlpha: 0.0)
        Self.morphIcon(cancelIcon, fromScale: 0.5, toScale: 1.0,
                       fromRotation: -.pi / 2, toRotation: 0.0,
                       fromAlpha: 0.0, toAlpha: 1.0)

        // Flight A -> B on two independent axis springs (FanTuning):
        // Y is fast with overshoot (rises above the line, settles down),
        // X is slower and smooth — together they trace an arc.
        let tuning = FanTuning.shared
        let source = CGPoint(x: sourceRect.midX, y: sourceRect.midY)
        for (index, view) in itemViews.enumerated() {
            let dest = view.center
            // Positive stagger: wave left-to-right (last cards delayed).
            // Negative: reversed — rightmost launches first.
            let staggerStep = Double(tuning.staggerMs) / 1000.0
            let order = staggerStep >= 0 ? Double(index) : Double(itemViews.count - 1 - index)
            let begin = CACurrentMediaTime() + order * abs(staggerStep)

            func axisSpring(_ keyPath: String, from: CGFloat, to: CGFloat,
                            stiffness: CGFloat, dampingRatio: CGFloat) -> CASpringAnimation {
                let spring = CASpringAnimation(keyPath: keyPath)
                spring.fromValue = from
                spring.toValue = to
                spring.mass = 1.0
                spring.stiffness = stiffness
                spring.damping = dampingRatio * 2.0 * sqrt(stiffness)
                spring.duration = spring.settlingDuration
                spring.beginTime = begin
                spring.fillMode = .backwards
                return spring
            }

            view.layer.add(axisSpring("position.x", from: source.x, to: dest.x,
                                      stiffness: tuning.xStiffness, dampingRatio: tuning.xDamping), forKey: "flightX")
            // The righter the card, the lower its Y damping — stronger overshoot.
            let yDampingForCard = max(0.2, tuning.yDamping - CGFloat(index) * tuning.yOvershootStep)
            view.layer.add(axisSpring("position.y", from: source.y + tuning.birthYOffset, to: dest.y,
                                      stiffness: tuning.yStiffness, dampingRatio: yDampingForCard), forKey: "flightY")
            view.layer.add(axisSpring("transform.scale", from: tuning.birthScale, to: 1.0,
                                      stiffness: tuning.xStiffness, dampingRatio: tuning.xDamping), forKey: "flightScale")

            // Alpha 0 -> 1 over 0.15s, starting with this card's launch.
            let fadeDelay = max(0.0, begin - CACurrentMediaTime())
            UIView.animate(withDuration: 0.15, delay: fadeDelay, options: [.allowUserInteraction, .curveEaseOut]) {
                view.alpha = 1.0
            }

            // Circle -> square: cornerRadius 34 -> 14 on the SAME spring as the
            // X axis, so shape morph always matches the flight speed.
            let corner = axisSpring("cornerRadius", from: 34.0, to: 14.0,
                                    stiffness: tuning.xStiffness, dampingRatio: tuning.xDamping)
            view.layer.add(corner, forKey: "cornerMorph")
            view.layer.cornerRadius = 14.0

            if let veil = view.viewWithTag(777) {
                let veilDuration = min(0.18, corner.settlingDuration * 0.4)
                UIView.animate(withDuration: veilDuration, delay: 0.0, options: [.allowUserInteraction, .curveEaseOut]) {
                    veil.alpha = 0.0
                } completion: { _ in
                    veil.removeFromSuperview()
                }
            }
        }
    }

    /// Pre-rendered gaussian blur for the birth defocus.
    private static func blurredImage(_ image: UIImage, radius: CGFloat) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let input = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        guard let rendered = context.createCGImage(output, from: input.extent) else { return nil }
        return UIImage(cgImage: rendered)
    }


    // MARK: - Finger tracking

    func updateTracking(location: CGPoint) {
        let newIndex = itemIndex(at: location)
        let overCancel = newIndex == nil && isOverCancel(location)

        if newIndex != highlightedIndex {
            if newIndex != nil {
                selectionHaptic.selectionChanged()
            }
            highlightedIndex = newIndex
            for (index, view) in itemViews.enumerated() {
                let highlighted = index == newIndex
                UIView.animate(withDuration: 0.28, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.4, options: [.allowUserInteraction]) {
                    view.transform = highlighted ? CGAffineTransform(scaleX: 1.18, y: 1.18) : .identity
                    view.layer.shadowOpacity = highlighted ? 0.25 : 0.0
                }
                if highlighted {
                    view.layer.shadowColor = UIColor.black.cgColor
                    view.layer.shadowRadius = 12
                    view.layer.shadowOffset = CGSize(width: 0, height: 6)
                    bringSubviewToFront(view)
                }
            }
        }

        if overCancel != cancelHighlighted {
            cancelHighlighted = overCancel
            if overCancel {
                selectionHaptic.selectionChanged()
            }
            UIView.animate(withDuration: 0.2, delay: 0.0, options: [.allowUserInteraction]) {
                self.cancelButton.transform = overCancel ? CGAffineTransform(scaleX: 1.2, y: 1.2) : .identity
            }
        }
    }

    /// Returns the index of the selected item at the release location, or nil for cancel.
    func finishTracking(location: CGPoint) -> Int? {
        return itemIndex(at: location)
    }

    private func itemIndex(at location: CGPoint) -> Int? {
        for (index, frame) in itemFrames.enumerated() {
            if frame.insetBy(dx: -hitSlop, dy: -hitSlop * 2).contains(location) {
                return index
            }
        }
        return nil
    }

    private func isOverCancel(_ location: CGPoint) -> Bool {
        return sourceRect.insetBy(dx: -hitSlop, dy: -hitSlop).contains(location)
    }

    // MARK: - Icon morph

    /// Scale + rotation + opacity ramp for one icon of the paperclip <-> ×
    /// morph. Every value is animated explicitly from `from` to `to` so the
    /// ramp survives a birth state assigned in the same runloop turn (a
    /// UIView animation would collapse it into a single frame).
    /// Current on-screen state of an icon: the presentation layer while the
    /// opening morph is still running, the settled values otherwise. Lets a
    /// dismissal that interrupts the opening continue from where the icon is.
    private static func iconState(_ view: UIView,
                                  scale: CGFloat,
                                  rotation: CGFloat,
                                  alpha: CGFloat) -> (scale: CGFloat, rotation: CGFloat, alpha: CGFloat) {
        guard let presentation = view.layer.presentation(),
              view.layer.animation(forKey: "morphScale") != nil else {
            return (scale, rotation, alpha)
        }
        let currentScale = (presentation.value(forKeyPath: "transform.scale.x") as? CGFloat) ?? scale
        let currentRotation = (presentation.value(forKeyPath: "transform.rotation.z") as? CGFloat) ?? rotation
        return (currentScale, currentRotation, CGFloat(presentation.opacity))
    }

    private static func morphIcon(_ view: UIView,
                                  fromScale: CGFloat, toScale: CGFloat,
                                  fromRotation: CGFloat, toRotation: CGFloat,
                                  fromAlpha: CGFloat, toAlpha: CGFloat) {
        let layer = view.layer
        let stiffness: CGFloat = 260
        let damping = 0.8 * 2.0 * sqrt(stiffness)

        func spring(_ keyPath: String, _ from: CGFloat, _ to: CGFloat) -> CASpringAnimation {
            let animation = CASpringAnimation(keyPath: keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.mass = 1.0
            animation.stiffness = stiffness
            animation.damping = damping
            animation.duration = animation.settlingDuration
            return animation
        }

        layer.add(spring("transform.scale", fromScale, toScale), forKey: "morphScale")
        layer.add(spring("transform.rotation.z", fromRotation, toRotation), forKey: "morphRotation")

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = fromAlpha
        fade.toValue = toAlpha
        fade.duration = 0.25
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(fade, forKey: "morphFade")

        view.transform = CGAffineTransform(rotationAngle: toRotation).scaledBy(x: toScale, y: toScale)
        view.alpha = toAlpha
    }

    // MARK: - Dismissal

    /// Dismisses the overlay. When `selectedIndex` is set, the selected thumbnail
    /// flies into `targetRect` (the attachment chip slot in the composer) while
    /// the rest melt away; otherwise everything collapses back into the button.
    func dismiss(selectedIndex: Int?, targetRect: CGRect?, completion: @escaping () -> Void) {
        // The flight springs may still be mid-air: bake each card's CURRENT
        // presentation position/scale into the model and drop the animations,
        // so every dismissal path continues seamlessly from where the card is.
        for view in itemViews {
            if let presentation = view.layer.presentation() {
                let scale = (presentation.value(forKeyPath: "transform.scale.x") as? CGFloat) ?? 1.0
                view.layer.removeAnimation(forKey: "flightX")
                view.layer.removeAnimation(forKey: "flightY")
                view.layer.removeAnimation(forKey: "flightScale")
                view.layer.position = presentation.position
                view.transform = CGAffineTransform(scaleX: scale, y: scale)
            }
        }

        // Reference video: blur clears ~200ms; unselected items fade together
        // in place with a slight shrink (~150ms); selected flies to the input
        // slot fast (~200ms + settle).
        UIView.animate(withDuration: 0.2, delay: 0.0) {
            self.blurView.effect = nil
            self.dimView.alpha = 0.0
        }
        // Icon-only morph back × -> paperclip; the circle stays put until the
        // overlay is removed and the real (identical) button reappears beneath.
        // Same explicit-spring treatment as the opening so both directions run
        // through the identical scale/rotation ramp.
        let cancelState = Self.iconState(cancelIcon, scale: 1.0, rotation: 0.0, alpha: 1.0)
        let attachState = Self.iconState(attachIconView, scale: 0.5, rotation: .pi / 2, alpha: 0.0)
        Self.morphIcon(cancelIcon, fromScale: cancelState.scale, toScale: 0.5,
                       fromRotation: cancelState.rotation, toRotation: -.pi / 2,
                       fromAlpha: cancelState.alpha, toAlpha: 0.0)
        Self.morphIcon(attachIconView, fromScale: attachState.scale, toScale: 1.0,
                       fromRotation: attachState.rotation, toRotation: 0.0,
                       fromAlpha: attachState.alpha, toAlpha: 1.0)
        UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.4) {
            self.cancelButton.transform = .identity
        }

        for (index, view) in itemViews.enumerated() {
            if index == selectedIndex { continue }
            if selectedIndex == nil {
                // TRUE mirror of the opening: same axis springs and stagger,
                // played backwards — the card that launched last returns first.
                let tuning = FanTuning.shared
                let target = CGPoint(x: sourceRect.midX, y: sourceRect.midY + tuning.birthYOffset)
                let fromPos = view.layer.position
                let fromScale = view.transform.a
                let staggerStep = Double(tuning.staggerMs) / 1000.0
                let reverseOrder = staggerStep >= 0 ? Double(itemViews.count - 1 - index) : Double(index)
                let begin = CACurrentMediaTime() + reverseOrder * abs(staggerStep)

                func reverseSpring(_ keyPath: String, from: CGFloat, to: CGFloat,
                                   stiffness: CGFloat, dampingRatio: CGFloat) -> CASpringAnimation {
                    let spring = CASpringAnimation(keyPath: keyPath)
                    spring.fromValue = from
                    spring.toValue = to
                    spring.mass = 1.0
                    spring.stiffness = stiffness
                    spring.damping = dampingRatio * 2.0 * sqrt(stiffness)
                    spring.duration = spring.settlingDuration
                    spring.beginTime = begin
                    spring.fillMode = .backwards
                    return spring
                }

                // To traverse the SAME arc backwards the axes swap speeds:
                // outbound the fast axis is Y (steep take-off), so on the way
                // back the fast axis is X (slide along the row first, then
                // drop down into the paperclip).
                let yDampingForCard = max(0.2, tuning.yDamping - CGFloat(index) * tuning.yOvershootStep)
                view.layer.position = target
                view.transform = CGAffineTransform(scaleX: tuning.birthScale, y: tuning.birthScale)
                view.layer.add(reverseSpring("position.x", from: fromPos.x, to: target.x,
                                             stiffness: tuning.yStiffness, dampingRatio: yDampingForCard), forKey: "foldX")
                view.layer.add(reverseSpring("position.y", from: fromPos.y, to: target.y,
                                             stiffness: tuning.xStiffness, dampingRatio: tuning.xDamping), forKey: "foldY")
                view.layer.add(reverseSpring("transform.scale", from: fromScale, to: tuning.birthScale,
                                             stiffness: tuning.xStiffness, dampingRatio: tuning.xDamping), forKey: "foldScale")
                view.layer.add(reverseSpring("cornerRadius", from: view.layer.cornerRadius, to: 34.0,
                                             stiffness: tuning.xStiffness, dampingRatio: tuning.xDamping), forKey: "cornerFold")
                view.layer.cornerRadius = 34.0

                // Alpha 1 -> 0 over 100ms ease-out, aligned with the return start.
                let fadeDelay = max(0.0, begin - CACurrentMediaTime())
                UIView.animate(withDuration: 0.10, delay: fadeDelay, options: [.curveEaseOut]) {
                    view.alpha = 0.0
                }
                // Defocus-out: the blurred copy ramps IN over the same 100ms up
                // to the birth blur level (sigma 10) — the mirror of the spawn.
                if !(view is CameraStripItemView), let image = view.image,
                   let blurred = Self.blurredImage(image, radius: 10) {
                    let veil = UIImageView(image: blurred)
                    veil.contentMode = .scaleAspectFill
                    veil.clipsToBounds = true
                    veil.frame = view.bounds
                    veil.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    veil.alpha = 0.0
                    view.addSubview(veil)
                    UIView.animate(withDuration: 0.10, delay: fadeDelay, options: [.curveEaseOut]) {
                        veil.alpha = 1.0
                    }
                }
            } else {
                UIView.animate(withDuration: 0.10, delay: 0.0, options: [.curveEaseOut]) {
                    view.alpha = 0.0
                    view.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
                }
            }
        }

        if let selectedIndex, let targetRect, selectedIndex < itemViews.count {
            let selected = itemViews[selectedIndex]
            bringSubviewToFront(selected)

            // The "×" badge fades in ON the flying thumbnail so it arrives
            // together with the image (black-40% circle, white xmark).
            let side = AttachmentBadge.side
            let badge = UIView()
            badge.backgroundColor = AttachmentBadge.circleColor
            badge.layer.cornerRadius = AttachmentBadge.cornerRadius
            let badgeIcon = AttachmentBadge.makeIcon()
            badgeIcon.frame = CGRect(x: 0, y: 0, width: side, height: side)
            badge.addSubview(badgeIcon)
            badge.frame = CGRect(x: selected.bounds.width - side - AttachmentBadge.inset,
                                 y: AttachmentBadge.inset, width: side, height: side)
            badge.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
            badge.alpha = 0.0
            selected.addSubview(badge)
            UIView.animate(withDuration: 0.32) {
                badge.alpha = 1.0
            }

            let cornerAnimation = CABasicAnimation(keyPath: "cornerRadius")
            cornerAnimation.fromValue = selected.layer.cornerRadius
            cornerAnimation.toValue = 10.0
            cornerAnimation.duration = 0.25
            selected.layer.add(cornerAnimation, forKey: "cornerRadius")
            selected.layer.cornerRadius = 10.0

            UIView.animate(withDuration: 0.32, delay: 0.0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: []) {
                selected.transform = .identity
                selected.frame = targetRect
                selected.layer.shadowOpacity = 0.0
            } completion: { _ in
                self.removeFromSuperview()
                completion()
            }
        } else {
            // Cards are fully faded by ~0.45s; no need to hold the overlay longer.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                self.removeFromSuperview()
                completion()
            }
        }
    }
}

/// The "×" badge on an attachment thumbnail. The overlay draws one on the
/// flying card and the composer draws the real one on the landed chip; the two
/// swap places at the end of the flight, so BOTH must come from here — a
/// UIButton renders the same symbol at its own point size and the swap shows
/// up as the badge jumping a size in one frame.
enum AttachmentBadge {
    static let side: CGFloat = 22
    static let cornerRadius: CGFloat = 11
    static let inset: CGFloat = 4
    static let circleColor = UIColor(white: 0.0, alpha: 0.4)

    /// White xmark, 10pt bold, centered — never scaled to its container.
    static func makeIcon() -> UIImageView {
        let icon = UIImageView(image: UIImage(systemName: "xmark",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)))
        icon.tintColor = .white
        icon.contentMode = .center
        icon.isUserInteractionEnabled = false
        return icon
    }
}

/// Live camera tile for the quick-attach strip: real viewfinder where a camera
/// exists (device), dark placeholder with the camera icon otherwise (simulator).
final class CameraStripItemView: UIImageView {
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let iconView = UIImageView()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = UIColor(white: 0.10, alpha: 1.0)

        iconView.image = UIImage(named: "AttachCamera")
        iconView.tintColor = .white
        iconView.contentMode = .center
        addSubview(iconView)

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device) {
            let session = AVCaptureSession()
            session.sessionPreset = .medium
            if session.canAddInput(input) {
                session.addInput(input)
                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                self.layer.insertSublayer(layer, at: 0)
                self.session = session
                self.previewLayer = layer
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                }
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        iconView.frame = bounds
        previewLayer?.frame = bounds
        if previewLayer != nil {
            iconView.isHidden = true
        }
    }

    deinit {
        if let session, session.isRunning {
            DispatchQueue.global(qos: .utility).async {
                session.stopRunning()
            }
        }
    }
}
