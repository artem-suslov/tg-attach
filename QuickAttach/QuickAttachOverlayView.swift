import UIKit

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
    private let cancelButton = UIView()
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
        dimView.backgroundColor = UIColor(white: 1.0, alpha: 0.25)
        dimView.alpha = 0.0
        addSubview(dimView)

        cancelButton.backgroundColor = UIColor(white: 0.35, alpha: 0.95)
        cancelIcon.image = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        cancelIcon.tintColor = .white
        cancelIcon.contentMode = .center
        cancelButton.addSubview(cancelIcon)
        addSubview(cancelButton)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Presentation

    /// - Parameter sourceRect: frame of the attach button in this view's coordinates (animation anchor).
    func present(images: [UIImage], from sourceRect: CGRect) {
        self.sourceRect = sourceRect
        impactHaptic.impactOccurred()
        selectionHaptic.prepare()

        // Cancel "×" appears exactly where the "+" button is, with a morph-like rotation.
        cancelButton.frame = sourceRect
        cancelButton.layer.cornerRadius = min(sourceRect.width, sourceRect.height) / 2
        cancelIcon.frame = cancelButton.bounds
        cancelButton.alpha = 0.0
        cancelButton.transform = CGAffineTransform(rotationAngle: -.pi / 2).scaledBy(x: 0.5, y: 0.5)

        // Layout the strip above the source button, left-aligned to it.
        itemFrames = []
        let count = images.count
        let stripY = sourceRect.minY - stripBottomGap - itemSide
        var x = sourceRect.minX
        let maxX = bounds.width - 8 - itemSide
        for _ in 0..<count {
            itemFrames.append(CGRect(x: min(x, maxX), y: stripY, width: itemSide, height: itemSide))
            x += itemSide + itemSpacing
        }

        itemViews = images.map { image in
            let view = UIImageView(image: image)
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
            view.layer.cornerRadius = 14
            view.layer.borderWidth = 0.5
            view.layer.borderColor = UIColor(white: 0.0, alpha: 0.08).cgColor
            addSubview(view)
            return view
        }

        // Start state: collapsed into the button's center.
        let sourceCenter = CGPoint(x: sourceRect.midX, y: sourceRect.midY)
        for (index, view) in itemViews.enumerated() {
            view.frame = itemFrames[index]
            view.alpha = 0.0
            let dx = sourceCenter.x - view.center.x
            let dy = sourceCenter.y - view.center.y
            view.transform = CGAffineTransform(translationX: dx, y: dy).scaledBy(x: 0.05, y: 0.05)
        }

        UIView.animate(withDuration: 0.25) {
            self.blurView.effect = UIBlurEffect(style: .systemUltraThinMaterialLight)
            self.dimView.alpha = 1.0
        }
        UIView.animate(withDuration: 0.35, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4, options: [.allowUserInteraction]) {
            self.cancelButton.alpha = 1.0
            self.cancelButton.transform = .identity
        }

        // Staggered spring fan-out, left to right.
        for (index, view) in itemViews.enumerated() {
            UIView.animate(withDuration: 0.42,
                           delay: 0.03 * Double(index),
                           usingSpringWithDamping: 0.68,
                           initialSpringVelocity: 0.5,
                           options: [.allowUserInteraction]) {
                view.alpha = 1.0
                view.transform = .identity
            }
        }
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

    // MARK: - Dismissal

    /// Dismisses the overlay. When `selectedIndex` is set, the selected thumbnail
    /// flies into `targetRect` (the attachment chip slot in the composer) while
    /// the rest melt away; otherwise everything collapses back into the button.
    func dismiss(selectedIndex: Int?, targetRect: CGRect?, completion: @escaping () -> Void) {
        let sourceCenter = CGPoint(x: sourceRect.midX, y: sourceRect.midY)

        UIView.animate(withDuration: 0.28, delay: selectedIndex != nil ? 0.05 : 0.0) {
            self.blurView.effect = nil
            self.dimView.alpha = 0.0
            self.cancelButton.alpha = 0.0
            self.cancelButton.transform = CGAffineTransform(rotationAngle: .pi / 2).scaledBy(x: 0.5, y: 0.5)
        }

        for (index, view) in itemViews.enumerated() {
            if index == selectedIndex { continue }
            UIView.animate(withDuration: 0.22, delay: 0.015 * Double(index), options: [.curveEaseIn]) {
                view.alpha = 0.0
                if selectedIndex == nil {
                    let dx = sourceCenter.x - view.center.x
                    let dy = sourceCenter.y - view.center.y
                    view.transform = CGAffineTransform(translationX: dx, y: dy).scaledBy(x: 0.05, y: 0.05)
                } else {
                    view.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
                }
            }
        }

        if let selectedIndex, let targetRect, selectedIndex < itemViews.count {
            let selected = itemViews[selectedIndex]
            bringSubviewToFront(selected)
            let cornerAnimation = CABasicAnimation(keyPath: "cornerRadius")
            cornerAnimation.fromValue = selected.layer.cornerRadius
            cornerAnimation.toValue = 10.0
            cornerAnimation.duration = 0.35
            selected.layer.add(cornerAnimation, forKey: "cornerRadius")
            selected.layer.cornerRadius = 10.0

            UIView.animate(withDuration: 0.45, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, options: []) {
                selected.transform = .identity
                selected.frame = targetRect
                selected.layer.shadowOpacity = 0.0
            } completion: { _ in
                self.removeFromSuperview()
                completion()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                self.removeFromSuperview()
                completion()
            }
        }
    }
}
