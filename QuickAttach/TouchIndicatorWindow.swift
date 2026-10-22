import UIKit

/// Window that draws a circle under every finger, so screen recordings of the
/// prototype show where the user touches and how long the press is held.
/// Purely visual: the overlay ignores touches and events are delivered as usual.
///
/// Taps, drags and scrolls keep the circle at full size. Only a finger that
/// stays put for `holdDelay` counts as a press and sinks the circle to
/// `heldScale`; once pressed it stays small while sliding (e.g. across the fan).
/// While the finger moves, the circle stretches along the direction of travel
/// in proportion to its speed and relaxes back to round when it slows down.
final class TouchIndicatorWindow: UIWindow {
    static var isEnabled = true

    private final class Indicator {
        /// Outer view: position plus appear / press / release scale animations.
        let view: UIView
        /// Inner circle: the speed stretch, driven every frame by the display link.
        let shape: UIView
        let origin: CGPoint
        var pressWork: DispatchWorkItem?
        var isHeld = false
        var lastLocation: CGPoint
        var lastTimestamp: TimeInterval?
        var lastMoveTime: CFTimeInterval = 0
        var velocity: CGVector = .zero
        /// Repeats the outward ripple for as long as the press is held.
        var rippleTimer: Timer?

        init(view: UIView, shape: UIView, origin: CGPoint) {
            self.view = view
            self.shape = shape
            self.origin = origin
            self.lastLocation = origin
        }
    }

    private let overlayView = UIView()
    private var indicators: [ObjectIdentifier: Indicator] = [:]
    private var stretchLink: CADisplayLink?

    private let diameter: CGFloat = 55
    /// Scale the circle settles to once the touch counts as a press.
    private let heldScale: CGFloat = 0.78
    /// Matches the sticker button's long-press minimumPressDuration.
    private let holdDelay: TimeInterval = 0.15
    /// Movement allowed before the press threshold; beyond it the touch is a drag.
    private let holdTolerance: CGFloat = 10
    /// Maximum elongation along the direction of travel (0.3 = 30% longer).
    private let maxStretch: CGFloat = 0.3
    /// Finger speed, in points per second, that reaches `maxStretch`.
    private let fullStretchSpeed: CGFloat = 2000

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        overlayView.isUserInteractionEnabled = false
        overlayView.backgroundColor = .clear
        addSubview(overlayView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        overlayView.frame = bounds
        bringSubviewToFront(overlayView)
    }

    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)
        guard Self.isEnabled, event.type == .touches, let touches = event.allTouches else { return }
        bringSubviewToFront(overlayView)
        for touch in touches {
            let key = ObjectIdentifier(touch)
            let location = touch.location(in: overlayView)
            switch touch.phase {
            case .began:
                show(key: key, at: location)
            case .moved:
                move(key: key, to: location, timestamp: touch.timestamp)
            case .stationary:
                indicators[key]?.view.center = location
            case .ended, .cancelled:
                hide(key: key)
            default:
                break
            }
        }
    }

    private func show(key: ObjectIdentifier, at location: CGPoint) {
        if let previous = indicators.removeValue(forKey: key) {
            previous.pressWork?.cancel()
            previous.rippleTimer?.invalidate()
            previous.view.removeFromSuperview()
        }
        let circle = UIView(frame: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        circle.center = location
        circle.backgroundColor = .clear
        circle.alpha = 0
        circle.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)

        let shape = UIView(frame: circle.bounds)
        shape.layer.cornerRadius = diameter / 2
        shape.backgroundColor = UIColor(white: 0.0, alpha: 0.18)
        shape.layer.borderColor = UIColor(white: 1.0, alpha: 0.9).cgColor
        shape.layer.borderWidth = 2
        shape.layer.shadowColor = UIColor.black.cgColor
        shape.layer.shadowOpacity = 0.15
        shape.layer.shadowRadius = 6
        shape.layer.shadowOffset = .zero
        circle.addSubview(shape)
        overlayView.addSubview(circle)

        let indicator = Indicator(view: circle, shape: shape, origin: location)
        indicators[key] = indicator
        startStretchLink()
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            circle.alpha = 1
            circle.transform = .identity
        }

        let work = DispatchWorkItem { [weak self, weak indicator] in
            guard let self, let indicator, !indicator.isHeld else { return }
            indicator.isHeld = true
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0,
                           options: [.beginFromCurrentState, .allowUserInteraction]) {
                indicator.view.transform = CGAffineTransform(scaleX: self.heldScale, y: self.heldScale)
            }
            self.startHoldRing(on: indicator)
        }
        indicator.pressWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDelay, execute: work)
    }

    private func move(key: ObjectIdentifier, to location: CGPoint, timestamp: TimeInterval) {
        guard let indicator = indicators[key] else { return }
        indicator.view.center = location
        // Moving away before the threshold makes this a drag or scroll, not a press.
        if !indicator.isHeld,
           hypot(location.x - indicator.origin.x, location.y - indicator.origin.y) > holdTolerance {
            indicator.pressWork?.cancel()
            indicator.pressWork = nil
        }
        // Smoothed finger velocity feeds the stretch on the next frame.
        if let lastTimestamp = indicator.lastTimestamp, timestamp > lastTimestamp {
            let dt = CGFloat(timestamp - lastTimestamp)
            let instant = CGVector(dx: (location.x - indicator.lastLocation.x) / dt,
                                   dy: (location.y - indicator.lastLocation.y) / dt)
            indicator.velocity = CGVector(dx: indicator.velocity.dx * 0.6 + instant.dx * 0.4,
                                          dy: indicator.velocity.dy * 0.6 + instant.dy * 0.4)
        }
        indicator.lastLocation = location
        indicator.lastTimestamp = timestamp
        indicator.lastMoveTime = CACurrentMediaTime()
    }

    private func hide(key: ObjectIdentifier) {
        guard let indicator = indicators.removeValue(forKey: key) else { return }
        indicator.pressWork?.cancel()
        indicator.rippleTimer?.invalidate()
        let circle = indicator.view
        // The circle pops: it collapses quickly while particles burst from its rim.
        let radius = diameter / 2 * (circle.layer.presentation()?.value(forKeyPath: "transform.scale.x") as? CGFloat ?? 1)
        burstParticles(at: circle.center, radius: radius)
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
            circle.alpha = 0
            circle.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            indicator.shape.transform = .identity
        } completion: { _ in
            circle.removeFromSuperview()
        }
    }

    private func burstParticles(at center: CGPoint, radius: CGFloat) {
        let count = 10
        let phase = CGFloat.random(in: 0..<(2 * .pi))
        for i in 0..<count {
            let angle = phase + 2 * .pi * CGFloat(i) / CGFloat(count) + CGFloat.random(in: -0.2...0.2)
            let size = CGFloat.random(in: 4...7)
            let direction = CGVector(dx: cos(angle), dy: sin(angle))
            let dot = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            dot.layer.cornerRadius = size / 2
            dot.backgroundColor = UIColor(white: 1.0, alpha: 0.95)
            dot.layer.shadowColor = UIColor.black.cgColor
            dot.layer.shadowOpacity = 0.2
            dot.layer.shadowRadius = 2
            dot.layer.shadowOffset = .zero
            dot.center = CGPoint(x: center.x + direction.dx * radius, y: center.y + direction.dy * radius)
            overlayView.addSubview(dot)

            let distance = CGFloat.random(in: 18...32)
            UIView.animate(withDuration: TimeInterval.random(in: 0.35...0.45), delay: 0, options: .curveEaseOut) {
                dot.center = CGPoint(x: dot.center.x + direction.dx * distance, y: dot.center.y + direction.dy * distance)
                dot.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
                dot.alpha = 0
            } completion: { _ in
                dot.removeFromSuperview()
            }
        }
    }

    // MARK: - Hold ring
    // Makes a press-and-hold readable in a screen recording: once the touch
    // counts as held, a ring draws itself around the circle like a progress
    // indicator, then soft ripples keep spreading out while the finger stays down.

    private let holdRingDuration: CFTimeInterval = 0.4
    private let rippleInterval: TimeInterval = 0.9

    private func ringPath() -> CGPath {
        let center = CGPoint(x: diameter / 2, y: diameter / 2)
        return UIBezierPath(arcCenter: center, radius: diameter / 2 + 8,
                            startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true).cgPath
    }

    private func startHoldRing(on indicator: Indicator) {
        let bounds = indicator.view.bounds
        let track = CAShapeLayer()
        track.frame = bounds
        track.path = ringPath()
        track.fillColor = UIColor.clear.cgColor
        track.strokeColor = UIColor(white: 1.0, alpha: 0.3).cgColor
        track.lineWidth = 3
        indicator.view.layer.addSublayer(track)

        let ring = CAShapeLayer()
        ring.frame = bounds
        ring.path = ringPath()
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = UIColor(white: 1.0, alpha: 0.95).cgColor
        ring.lineWidth = 3
        ring.lineCap = .round
        ring.shadowColor = UIColor.black.cgColor
        ring.shadowOpacity = 0.2
        ring.shadowRadius = 3
        ring.shadowOffset = .zero
        indicator.view.layer.addSublayer(ring)

        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = holdRingDuration
        draw.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        ring.add(draw, forKey: "draw")

        // Once the ring closes, ripples keep signalling "still holding".
        DispatchQueue.main.asyncAfter(deadline: .now() + holdRingDuration) { [weak self, weak indicator] in
            guard let self, let indicator, indicator.view.superview != nil,
                  self.indicators.values.contains(where: { $0 === indicator }) else { return }
            self.emitRipple(on: indicator)
            indicator.rippleTimer = Timer.scheduledTimer(withTimeInterval: self.rippleInterval, repeats: true) { [weak self, weak indicator] _ in
                guard let self, let indicator else { return }
                self.emitRipple(on: indicator)
            }
        }
    }

    private func emitRipple(on indicator: Indicator) {
        let ripple = CAShapeLayer()
        ripple.frame = indicator.view.bounds
        ripple.path = ringPath()
        ripple.fillColor = UIColor.clear.cgColor
        ripple.strokeColor = UIColor(white: 1.0, alpha: 0.7).cgColor
        ripple.lineWidth = 2
        ripple.opacity = 0
        indicator.view.layer.insertSublayer(ripple, at: 0)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = 1.6
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.9
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        CATransaction.begin()
        CATransaction.setCompletionBlock { ripple.removeFromSuperlayer() }
        ripple.add(group, forKey: "ripple")
        CATransaction.commit()
    }

    // MARK: - Speed stretch

    private func startStretchLink() {
        guard stretchLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(updateStretch))
        link.add(to: .main, forMode: .common)
        stretchLink = link
    }

    @objc private func updateStretch() {
        guard !indicators.isEmpty else {
            stretchLink?.invalidate()
            stretchLink = nil
            return
        }
        let now = CACurrentMediaTime()
        for indicator in indicators.values {
            // No fresh movement this frame: let the velocity, and the stretch, decay.
            if now - indicator.lastMoveTime > 1.0 / 60.0 {
                indicator.velocity = CGVector(dx: indicator.velocity.dx * 0.8, dy: indicator.velocity.dy * 0.8)
            }
            let speed = hypot(indicator.velocity.dx, indicator.velocity.dy)
            guard speed > 1 else {
                indicator.shape.transform = .identity
                continue
            }
            let stretch = min(maxStretch, speed / fullStretchSpeed * maxStretch)
            let angle = atan2(indicator.velocity.dy, indicator.velocity.dx)
            // Longer along the motion, slightly thinner across it.
            indicator.shape.transform = CGAffineTransform(rotationAngle: angle)
                .scaledBy(x: 1 + stretch, y: 1 / (1 + stretch * 0.5))
                .rotated(by: -angle)
        }
    }
}
