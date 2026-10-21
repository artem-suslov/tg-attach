import UIKit

/// Full-screen long-press surface for the quick-sticker gesture. Cards are
/// launched from the sticker icon on independent X/Y springs so their path bends
/// naturally instead of travelling in a straight line.
///
/// The cards live in a horizontal strip. While the finger is down only the
/// recent stickers are shown; dragging above the strip and releasing pins it
/// in place, where it scrolls sideways to reveal the rest of the pack and a tap
/// sends a sticker.
final class QuickStickerOverlayView: UIView {
    var onTap: ((CGPoint) -> Void)?
    private let dimView = UIView()
    private let stripView = UIScrollView()
    private var itemViews: [StickerPreviewView] = []
    private var recentCount = 0
    private var sourceRect: CGRect = .zero
    /// Resting frame of the strip, kept apart from its pin-preview lift transform.
    private var stripRect: CGRect = .zero
    private var highlightedIndex: Int?
    private var isPinPreview = false
    private(set) var isPinned = false
    private let selectionHaptic = UISelectionFeedbackGenerator()
    private let impactHaptic = UIImpactFeedbackGenerator(style: .medium)

    private let itemSpacing: CGFloat = 5
    private let stripBottomGap: CGFloat = 16
    private let hitSlop: CGFloat = 12
    /// How far above the strip the finger has to travel for a release to pin it.
    private let pinThreshold: CGFloat = 16
    /// Vertical room around the cards so the highlight scale isn't clipped.
    private let stripPadding: CGFloat = 10

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        dimView.frame = bounds
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Keep the conversation readable: the fan needs just enough contrast,
        // not a modal blur that hides the chat context.
        dimView.backgroundColor = UIColor(white: 0, alpha: 0.04)
        dimView.alpha = 0
        addSubview(dimView)

        stripView.clipsToBounds = false
        stripView.isScrollEnabled = false
        stripView.showsHorizontalScrollIndicator = false
        stripView.showsVerticalScrollIndicator = false
        stripView.alwaysBounceHorizontal = true
        stripView.contentInsetAdjustmentBehavior = .never
        addSubview(stripView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        onTap?(recognizer.location(in: self))
    }

    /// `recent` fan out from the icon; `more` wait to the right of them and
    /// only appear once the strip is pinned.
    func present(recent: [StickerAsset], more: [StickerAsset], from sourceRect: CGRect) {
        guard !recent.isEmpty else { return }
        self.sourceRect = sourceRect
        recentCount = recent.count
        impactHaptic.impactOccurred()
        selectionHaptic.prepare()

        // Keep the source aspect ratio for every item. A square preview frame
        // made rectangular stickers look as if the app had painted a backing
        // card underneath them.
        let maximumEdge: CGFloat = 80
        func unscaledSize(_ sticker: StickerAsset) -> CGSize {
            let ratio = max(0.2, sticker.aspectRatio)
            return ratio >= 1
                ? CGSize(width: maximumEdge, height: maximumEdge / ratio)
                : CGSize(width: maximumEdge * ratio, height: maximumEdge)
        }
        let recentSizes = recent.map(unscaledSize)
        let availableWidth = bounds.width - 16 - itemSpacing * CGFloat(recent.count - 1)
        let unscaledWidth = recentSizes.reduce(0) { $0 + $1.width }
        let scale = min(1, availableWidth / max(1, unscaledWidth))
        let itemSizes = (recent + more).map { sticker -> CGSize in
            let size = unscaledSize(sticker)
            return CGSize(width: size.width * scale, height: size.height * scale)
        }
        let recentItemSizes = Array(itemSizes.prefix(recent.count))
        let stripWidth = recentItemSizes.reduce(0) { $0 + $1.width } + itemSpacing * CGFloat(recent.count - 1)
        let maxHeight = itemSizes.map(\.height).max() ?? maximumEdge
        let rightmostWidth = recentItemSizes.last?.width ?? 0
        let x = max(8, min(sourceRect.midX - stripWidth + rightmostWidth / 2, bounds.width - 8 - stripWidth))
        let y = max(safeAreaInsets.top + 8, sourceRect.minY - stripBottomGap - maxHeight)

        // The strip spans the screen width; once pinned it scrolls sideways and
        // the screen edges do the clipping.
        stripRect = CGRect(x: 0, y: y - stripPadding, width: bounds.width, height: maxHeight + stripPadding * 2)
        stripView.frame = stripRect
        var nextX = x
        let itemFrames = itemSizes.map { size -> CGRect in
            defer { nextX += size.width + itemSpacing }
            return CGRect(x: nextX, y: stripPadding + (maxHeight - size.height) / 2, width: size.width, height: size.height)
        }
        stripView.contentSize = CGSize(width: (itemFrames.last?.maxX ?? 0) + x, height: stripRect.height)

        itemViews = zip(recent + more, itemFrames).map { sticker, frame in
            let view = StickerPreviewView(cornerRadius: sticker.cornerRadius)
            view.layer.cornerCurve = .continuous
            view.configure(with: sticker)
            view.frame = frame
            view.alpha = 0
            view.layer.allowsEdgeAntialiasing = true
            stripView.addSubview(view)
            return view
        }

        UIView.animate(withDuration: 0.12) {
            self.dimView.alpha = 1
        }

        let tuning = FanTuning.shared
        let source = stripView.convert(CGPoint(x: sourceRect.midX, y: sourceRect.midY), from: self)
        for (index, view) in itemViews.prefix(recentCount).enumerated() {
            let destination = view.center
            let begin = CACurrentMediaTime() + Double(index) * Double(tuning.staggerMs) / 1000
            let yDamping = max(0.2, tuning.yDamping - CGFloat(index) * tuning.yOvershootStep)
            view.layer.add(spring("position.x", from: source.x, to: destination.x, stiffness: tuning.xStiffness, dampingRatio: tuning.xDamping, begin: begin), forKey: "flightX")
            view.layer.add(spring("position.y", from: source.y, to: destination.y, stiffness: tuning.yStiffness, dampingRatio: yDamping, begin: begin), forKey: "flightY")
            view.layer.add(spring("transform.scale", from: tuning.birthScale, to: 1, stiffness: tuning.xStiffness, dampingRatio: tuning.xDamping, begin: begin), forKey: "flightScale")
            UIView.animate(withDuration: 0.15, delay: max(0, begin - CACurrentMediaTime()), options: .curveEaseOut) {
                view.alpha = 1
            }
        }
    }

    func updateTracking(location: CGPoint) {
        let next = itemIndex(at: location)
        setPinPreview(next == nil && location.y < stripRect.minY - pinThreshold)
        guard next != highlightedIndex else { return }
        if next != nil { selectionHaptic.selectionChanged() }
        highlightedIndex = next
        for (index, view) in itemViews.prefix(recentCount).enumerated() {
            let isHighlighted = index == next
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.4, options: .allowUserInteraction) {
                view.transform = isHighlighted ? CGAffineTransform(scaleX: 1.18, y: 1.18) : .identity
                view.alpha = next == nil || isHighlighted ? 1 : 0.8
            }
            if isHighlighted {
                stripView.bringSubviewToFront(view)
            }
        }
    }

    func finishTracking(location: CGPoint) -> Int? { itemIndex(at: location) }

    /// True when the finger was released above the strip: pin instead of closing.
    func shouldPin(at location: CGPoint) -> Bool {
        !isPinned && itemIndex(at: location) == nil && location.y < stripRect.minY - pinThreshold
    }

    func pin() {
        guard !isPinned else { return }
        isPinned = true
        isPinPreview = false
        highlightedIndex = nil
        impactHaptic.impactOccurred(intensity: 0.6)
        stripView.isScrollEnabled = true
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.stripView.transform = .identity
            for view in self.itemViews.prefix(self.recentCount) {
                view.transform = .identity
                view.alpha = 1
            }
        }
        // The rest of the pack slides in from the right, one after another.
        for (offset, view) in itemViews.dropFirst(recentCount).enumerated() {
            view.transform = CGAffineTransform(translationX: 24, y: 0)
            UIView.animate(withDuration: 0.35, delay: 0.04 * Double(offset), usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
                view.alpha = 1
                view.transform = .identity
            }
        }
    }

    func playbackStart(at index: Int) -> CFTimeInterval? {
        itemViews.indices.contains(index) ? itemViews[index].playbackStart : nil
    }

    /// `targetRect` is the message's final frame in this view. If the chat list
    /// is still gliding to its new bottom, pass that glide as `followScroll`:
    /// the card replays it on top of its own flight, so it tracks the message
    /// and lands on it exactly while staying above the edge blur.
    func dismiss(selectedIndex: Int?, targetRect: CGRect?, followScroll: CASpringAnimation? = nil,
                 completion: @escaping () -> Void) {
        for view in itemViews { bakePresentationState(into: view) }
        UIView.animate(withDuration: 0.18) {
            self.dimView.alpha = 0
        }

        if let selectedIndex, let targetRect, itemViews.indices.contains(selectedIndex) {
            for (index, view) in itemViews.enumerated() where index != selectedIndex {
                UIView.animate(withDuration: 0.12, delay: 0, options: .curveEaseOut) {
                    view.alpha = 0
                    view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                }
            }
            // Lift the chosen card out of the (possibly scrolled) strip so it
            // can fly to its message.
            let selected = itemViews[selectedIndex]
            let center = stripView.convert(selected.center, to: self)
            addSubview(selected)
            selected.center = center
            UIView.animate(withDuration: 0.30, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.35) {
                selected.transform = .identity
                selected.frame = targetRect
                selected.layer.shadowOpacity = 0
            } completion: { _ in
                self.removeFromSuperview()
                completion()
            }
            if let followScroll, let scrollFrom = followScroll.fromValue as? CGFloat {
                // The list's glide shifts content on screen by -scrollFrom → 0.
                let follow = CASpringAnimation(keyPath: "position.y")
                follow.fromValue = -scrollFrom
                follow.toValue = 0
                follow.isAdditive = true
                follow.mass = followScroll.mass
                follow.stiffness = followScroll.stiffness
                follow.damping = followScroll.damping
                follow.duration = followScroll.duration
                selected.layer.add(follow, forKey: "followScroll")
            }
            return
        }

        if isPinned {
            // A pinned, possibly scrolled strip closes in place rather than
            // folding cards that may be far off to the side back into the icon.
            UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseIn) {
                self.stripView.alpha = 0
                self.stripView.transform = CGAffineTransform(translationX: 0, y: 12).scaledBy(x: 0.96, y: 0.96)
            } completion: { _ in
                self.removeFromSuperview()
                completion()
            }
            return
        }

        let tuning = FanTuning.shared
        let target = stripView.convert(CGPoint(x: sourceRect.midX, y: sourceRect.midY + tuning.birthYOffset), from: self)
        for (index, view) in itemViews.prefix(recentCount).enumerated() {
            let reverseOrder = Double(recentCount - 1 - index) * Double(tuning.staggerMs) / 1000
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

    /// While the finger is above the strip, the strip lifts a little as a hint
    /// that letting go here will pin it.
    private func setPinPreview(_ preview: Bool) {
        guard !isPinned, preview != isPinPreview else { return }
        isPinPreview = preview
        if preview { selectionHaptic.selectionChanged() }
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .allowUserInteraction) {
            self.stripView.transform = preview ? CGAffineTransform(translationX: 0, y: -8) : .identity
        }
    }

    private func itemIndex(at location: CGPoint) -> Int? {
        let visibleCount = isPinned ? itemViews.count : recentCount
        for index in 0..<visibleCount {
            let view = itemViews[index]
            // Model geometry, not the highlight transform, so hit areas stay put.
            let local = CGRect(x: view.center.x - view.bounds.width / 2, y: view.center.y - view.bounds.height / 2,
                               width: view.bounds.width, height: view.bounds.height)
            let rect = stripView.convert(local, to: self).insetBy(dx: -hitSlop, dy: -hitSlop * 2)
            if rect.contains(location) { return index }
        }
        return nil
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
