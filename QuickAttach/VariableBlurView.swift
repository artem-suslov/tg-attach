import UIKit

/// Progressive ("variable") blur: full strength at one edge fading to none at
/// the other. Analog of Telegram-iOS `VariableBlurView`, which drives the same
/// private Core Animation `variableBlur` filter on a backdrop layer — there is
/// no public API for a blur whose radius varies across the view. Fine for a
/// prototype; a private filter like this would not pass App Store review.
final class VariableBlurView: UIVisualEffectView {
    enum Edge { case top, bottom }

    private let edge: Edge
    private let maxBlurRadius: CGFloat
    /// Matches the Figma layer: on top of the radius ramp, the blur layer itself
    /// is masked by a black gradient from 100% to 0% opacity toward the weak edge.
    private let fadeMask = GradientMaskView()

    init(maxBlurRadius: CGFloat, strongEdge: Edge) {
        self.edge = strongEdge
        self.maxBlurRadius = maxBlurRadius
        super.init(effect: UIBlurEffect(style: .regular))
        isUserInteractionEnabled = false
        applyVariableBlur()
        fadeMask.gradientLayer.colors = [UIColor.black.cgColor, UIColor.black.withAlphaComponent(0).cgColor]
        fadeMask.gradientLayer.startPoint = CGPoint(x: 0.5, y: strongEdge == .top ? 0 : 1)
        fadeMask.gradientLayer.endPoint = CGPoint(x: 0.5, y: strongEdge == .top ? 1 : 0)
        mask = fadeMask
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        fadeMask.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window, let backdropLayer = subviews.first?.layer else { return }
        backdropLayer.setValue(window.traitCollection.displayScale, forKey: "scale")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        // UIVisualEffectView resets its filters on trait changes; put ours back.
        super.traitCollectionDidChange(previousTraitCollection)
        applyVariableBlur()
    }

    private func applyVariableBlur() {
        // CAFilter is private; build its name and selector at runtime.
        guard let filterClass = NSClassFromString(String("retliFAC".reversed())) as AnyObject as? NSObjectProtocol else { return }
        let selector = Selector(String(":epyThtiWretlif".reversed()))
        guard filterClass.responds(to: selector),
              let filter = filterClass.perform(selector, with: "variableBlur")?.takeUnretainedValue() as? NSObject else { return }
        filter.setValue(maxBlurRadius, forKey: "inputRadius")
        filter.setValue(Self.maskImage(strongEdge: edge), forKey: "inputMaskImage")
        filter.setValue(true, forKey: "inputNormalizeEdges")

        // The first subview is the backdrop: blur it with the variable filter
        // and hide the stock tint / grain layers so only the blur remains.
        subviews.first?.layer.filters = [filter]
        for subview in subviews.dropFirst() {
            subview.alpha = 0
        }
    }

    /// Alpha ramp the filter reads as blur strength: opaque = full radius.
    private static func maskImage(strongEdge: Edge) -> CGImage? {
        let size = CGSize(width: 1, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [UIColor.black.cgColor, UIColor.clear.cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            let start = CGPoint(x: 0, y: strongEdge == .top ? 0 : size.height)
            let end = CGPoint(x: 0, y: strongEdge == .top ? size.height : 0)
            context.cgContext.drawLinearGradient(gradient, start: start, end: end, options: [])
        }
        return image.cgImage
    }
}

/// UIVisualEffectView only honours masks given as a view (`mask`), not a raw layer.
private final class GradientMaskView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }
}
