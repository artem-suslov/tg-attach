import UIKit

/// Full-screen long-press surface for the quick-sticker gesture. Cards are
/// launched from the sticker icon on independent X/Y springs so their path bends
/// naturally instead of travelling in a straight line.
final class QuickStickerOverlayView: UIView {
    var onTap: ((CGPoint) -> Void)?
    private let blurView = UIVisualEffectView(effect: nil)
    private let dimView = UIView()
    private var itemViews: [UIImageView] = []
    private var itemFrames: [CGRect] = []
    private var sourceRect: CGRect = .zero
    private var highlightedIndex: Int?
    private let selectionHaptic = UISelectionFeedbackGenerator()
    private let impactHaptic = UIImpactFeedbackGenerator(style: .medium)

    private let itemSpacing: CGFloat = 5
    private let stripBottomGap: CGFloat = 16
    private let hitSlop: CGFloat = 12

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurView)
        dimView.frame = bounds
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimView.backgroundColor = UIColor(white: 1, alpha: 0.12)
        dimView.alpha = 0
        addSubview(dimView)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        onTap?(recognizer.location(in: self))
    }

    func present(stickers: [UIImage], from sourceRect: CGRect) {
        guard !stickers.isEmpty else { return }
        self.sourceRect = sourceRect
        impactHaptic.impactOccurred()
        selectionHaptic.prepare()

        let count = CGFloat(stickers.count)
        let availableWidth = bounds.width - 16 - itemSpacing * (count - 1)
        let itemSide = min(64, max(48, floor(availableWidth / count)))
        let stripWidth = itemSide * count + itemSpacing * (count - 1)
        let x = max(8, min(sourceRect.midX - stripWidth + itemSide / 2, bounds.width - 8 - stripWidth))
        let y = max(safeAreaInsets.top + 8, sourceRect.minY - stripBottomGap - itemSide)
        itemFrames = stickers.indices.map {
            CGRect(x: x + CGFloat($0) * (itemSide + itemSpacing), y: y, width: itemSide, height: itemSide)
        }

        itemViews = zip(stickers, itemFrames).map { image, frame in
            let view = UIImageView(image: image)
            view.contentMode = .scaleAspectFit
            view.frame = frame
            view.alpha = 0
            view.layer.cornerRadius = itemSide / 2
            view.layer.cornerCurve = .continuous
            addSubview(view)
            return view
        }

        UIView.animate(withDuration: 0.12) {
            self.blurView.effect = UIBlurEffect(style: .systemUltraThinMaterialLight)
            self.dimView.alpha = 1
        }

        let tuning = FanTuning.shared
        let source = CGPoint(x: sourceRect.midX, y: sourceRect.midY)
        for (index, view) in itemViews.enumerated() {
            let destination = view.center
            let begin = CACurrentMediaTime() + Double(index) * Double(tuning.staggerMs) / 1000
            let yDamping = max(0.2, tuning.yDamping - CGFloat(index) * tuning.yOvershootStep)
            view.layer.add(spring("position.x", from: source.x, to: destination.x, stiffness: tuning.xStiffness, dampingRatio: tuning.xDamping, begin: begin), forKey: "flightX")
            view.layer.add(spring("position.y", from: source.y, to: destination.y, stiffness: tuning.yStiffness, dampingRatio: yDamping, begin: begin), forKey: "flightY")
            view.layer.add(spring("transform.scale", from: tuning.birthScale, to: 1, stiffness: tuning.xStiffness, dampingRatio: tuning.xDamping, begin: begin), forKey: "flightScale")
            view.layer.add(spring("cornerRadius", from: itemSide / 2, to: 12, stiffness: tuning.xStiffness, dampingRatio: tuning.xDamping, begin: begin), forKey: "cornerMorph")
            view.layer.cornerRadius = 12
            UIView.animate(withDuration: 0.15, delay: max(0, begin - CACurrentMediaTime()), options: .curveEaseOut) {
                view.alpha = 1
            }
        }
    }

    func updateTracking(location: CGPoint) {
        let next = itemIndex(at: location)
        guard next != highlightedIndex else { return }
        if next != nil { selectionHaptic.selectionChanged() }
        highlightedIndex = next
        for (index, view) in itemViews.enumerated() {
            let isHighlighted = index == next
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.4, options: .allowUserInteraction) {
                view.transform = isHighlighted ? CGAffineTransform(scaleX: 1.18, y: 1.18) : .identity
                view.layer.shadowOpacity = isHighlighted ? 0.24 : 0
            }
            if isHighlighted {
                view.layer.shadowColor = UIColor.black.cgColor
                view.layer.shadowRadius = 10
                view.layer.shadowOffset = CGSize(width: 0, height: 5)
                bringSubviewToFront(view)
            }
        }
    }

    func finishTracking(location: CGPoint) -> Int? { itemIndex(at: location) }

    func dismiss(selectedIndex: Int?, targetRect: CGRect?, completion: @escaping () -> Void) {
        for view in itemViews { bakePresentationState(into: view) }
        UIView.animate(withDuration: 0.18) {
            self.blurView.effect = nil
            self.dimView.alpha = 0
        }

        if let selectedIndex, let targetRect, itemViews.indices.contains(selectedIndex) {
            for (index, view) in itemViews.enumerated() where index != selectedIndex {
                UIView.animate(withDuration: 0.12, delay: 0, options: .curveEaseOut) {
                    view.alpha = 0
                    view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                }
            }
            let selected = itemViews[selectedIndex]
            bringSubviewToFront(selected)
            UIView.animate(withDuration: 0.30, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.35) {
                selected.transform = .identity
                selected.frame = targetRect
                selected.layer.shadowOpacity = 0
            } completion: { _ in
                self.removeFromSuperview()
                completion()
            }
            return
        }

        let tuning = FanTuning.shared
        let target = CGPoint(x: sourceRect.midX, y: sourceRect.midY + tuning.birthYOffset)
        for (index, view) in itemViews.enumerated() {
            let reverseOrder = Double(itemViews.count - 1 - index) * Double(tuning.staggerMs) / 1000
            let begin = CACurrentMediaTime() + reverseOrder
            let yDamping = max(0.2, tuning.yDamping - CGFloat(index) * tuning.yOvershootStep)
            let fromPosition = view.layer.position
            let fromScale = view.transform.a
            view.layer.position = target
            view.transform = CGAffineTransform(scaleX: tuning.birthScale, y: tuning.birthScale)
            view.layer.add(spring("position.x", from: fromPosition.x, to: target.x, stiffness: tuning.yStiffness, dampingRatio: yDamping, begin: begin), forKey: "foldX")
            view.layer.add(spring("position.y", from: fromPosition.y, to: target.y, stiffness: tuning.xStiffness, dampingRatio: tuning.xDamping, begin: begin), forKey: "foldY")
            view.layer.add(spring("transform.scale", from: fromScale, to: tuning.birthScale, stiffness: tuning.xStiffness, dampingRatio: tuning.xDamping, begin: begin), forKey: "foldScale")
            UIView.animate(withDuration: 0.10, delay: max(0, begin - CACurrentMediaTime()), options: .curveEaseOut) { view.alpha = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.removeFromSuperview()
            completion()
        }
    }

    private func itemIndex(at location: CGPoint) -> Int? {
        itemFrames.firstIndex { $0.insetBy(dx: -hitSlop, dy: -hitSlop * 2).contains(location) }
    }

    private func spring(_ keyPath: String, from: CGFloat, to: CGFloat, stiffness: CGFloat, dampingRatio: CGFloat, begin: CFTimeInterval) -> CASpringAnimation {
        let animation = CASpringAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.mass = 1
        animation.stiffness = stiffness
        animation.damping = dampingRatio * 2 * sqrt(stiffness)
        animation.duration = animation.settlingDuration
        animation.beginTime = begin
        animation.fillMode = .backwards
        return animation
    }

    private func bakePresentationState(into view: UIView) {
        guard let presentation = view.layer.presentation() else { return }
        let scale = (presentation.value(forKeyPath: "transform.scale.x") as? CGFloat) ?? 1
        view.layer.removeAllAnimations()
        view.layer.position = presentation.position
        view.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
}
