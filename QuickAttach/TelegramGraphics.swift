import UIKit

/// Graphics transcribed from the official Telegram-iOS source (HEAD 6ad963e).
/// Every constant below is copied verbatim from the referenced file.
enum TelegramGraphics {

    static let screenPixel: CGFloat = 1.0 / UIScreen.main.scale

    // MARK: - Message bubble
    // Transcribed from submodules/TelegramPresentationData/Sources/ChatMessageBubbleImages.swift.

    enum BubbleNeighbors {
        case none    // standalone message: full radii + tail
        case top     // first of a group
        case both    // middle of a group
        case bottom  // last of a group: merged top corner + tail
    }

    static let bubbleMainRadius: CGFloat = 16.0     // PresentationThemeSettings mainRadius
    static let bubbleAuxRadius: CGFloat = 8.0       // auxiliaryRadius
    private static let minRadiusForFullTailCorner: CGFloat = 14.0

    /// Stretchable bubble image with Telegram's exact geometry: 33pt template,
    /// tail from bottomEllipse(24,16,27x17) quad curves with topEllipse(33,14,23x21)
    /// punched out, hairline stroke at UIScreenPixel + 0.25.
    static func messageBubbleImage(incoming: Bool,
                                   fillColor: UIColor,
                                   strokeColor: UIColor,
                                   neighbors: BubbleNeighbors) -> UIImage {
        let maxCornerRadius = bubbleMainRadius
        let minCornerRadius = bubbleAuxRadius

        let topLeftRadius: CGFloat
        let topRightRadius: CGFloat
        let bottomLeftRadius: CGFloat
        let bottomRightRadius: CGFloat
        let drawTail: Bool
        switch neighbors {
        case .none:
            topLeftRadius = maxCornerRadius; topRightRadius = maxCornerRadius
            bottomLeftRadius = maxCornerRadius; bottomRightRadius = maxCornerRadius
            drawTail = true
        case .both:
            topLeftRadius = maxCornerRadius; topRightRadius = minCornerRadius
            bottomLeftRadius = maxCornerRadius; bottomRightRadius = minCornerRadius
            drawTail = false
        case .bottom:
            topLeftRadius = maxCornerRadius; topRightRadius = minCornerRadius
            bottomLeftRadius = maxCornerRadius; bottomRightRadius = maxCornerRadius
            drawTail = true
        case .top:
            topLeftRadius = maxCornerRadius; topRightRadius = maxCornerRadius
            bottomLeftRadius = maxCornerRadius; bottomRightRadius = minCornerRadius
            drawTail = false
        }

        let fixedMainDiameter: CGFloat = 33.0
        let innerSize = CGSize(width: fixedMainDiameter + 6.0, height: fixedMainDiameter)
        let strokeInset: CGFloat = 1.0
        let sourceRawSize = CGSize(width: innerSize.width + strokeInset * 2.0, height: innerSize.height + strokeInset * 2.0)
        let additionalInset: CGFloat = 1.0
        let imageSize = CGSize(width: sourceRawSize.width + additionalInset * 2.0, height: sourceRawSize.height + additionalInset * 2.0)

        let bottomEllipse = CGRect(origin: CGPoint(x: 24.0, y: 16.0), size: CGSize(width: 27.0, height: 17.0))
        let topEllipse = CGRect(origin: CGPoint(x: 33.0, y: 14.0), size: CGSize(width: 23.0, height: 21.0))

        let borderOffset: CGFloat
        let borderWidth: CGFloat
        if abs(screenPixel - 0.5) < CGFloat.ulpOfOne {
            borderWidth = screenPixel + 0.25
            borderOffset = -0.25 / 2.0 + screenPixel / 2.0
        } else {
            borderWidth = screenPixel + 0.25
            borderOffset = -0.25 / 2.0
        }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        let image = renderer.image { rendererContext in
            let context = rendererContext.cgContext
            if incoming {
                // Mirror the outgoing template horizontally (tail moves to the left).
                context.translateBy(x: imageSize.width, y: 0.0)
                context.scaleBy(x: -1.0, y: 1.0)
            }
            context.translateBy(x: additionalInset + strokeInset, y: additionalInset + strokeInset)

            func addBubblePath(offset o: CGFloat) {
                context.move(to: CGPoint(x: -o, y: topLeftRadius + o))
                context.addArc(tangent1End: CGPoint(x: -o, y: -o), tangent2End: CGPoint(x: topLeftRadius + o, y: -o), radius: topLeftRadius + o * 2.0)
                context.addLine(to: CGPoint(x: fixedMainDiameter - topRightRadius - o, y: -o))
                context.addArc(tangent1End: CGPoint(x: fixedMainDiameter + o, y: -o), tangent2End: CGPoint(x: fixedMainDiameter + o, y: topRightRadius + o), radius: topRightRadius + o * 2.0)
                context.addLine(to: CGPoint(x: fixedMainDiameter + o, y: fixedMainDiameter - bottomRightRadius - o))
                context.addArc(tangent1End: CGPoint(x: fixedMainDiameter + o, y: fixedMainDiameter + o), tangent2End: CGPoint(x: fixedMainDiameter - bottomRightRadius - o, y: fixedMainDiameter + o), radius: bottomRightRadius + o * 2.0)
                context.addLine(to: CGPoint(x: bottomLeftRadius + o, y: fixedMainDiameter + o))
                context.addArc(tangent1End: CGPoint(x: -o, y: fixedMainDiameter + o), tangent2End: CGPoint(x: -o, y: fixedMainDiameter - bottomLeftRadius - o), radius: bottomLeftRadius + o * 2.0)
                context.addLine(to: CGPoint(x: -o, y: topLeftRadius + o))
            }

            // Form (fill).
            context.setFillColor(fillColor.cgColor)
            addBubblePath(offset: 0.0)
            context.fillPath()

            if drawTail {
                context.move(to: CGPoint(x: bottomEllipse.minX, y: bottomEllipse.midY))
                context.addQuadCurve(to: CGPoint(x: bottomEllipse.midX, y: bottomEllipse.maxY), control: CGPoint(x: bottomEllipse.minX, y: bottomEllipse.maxY))
                context.addQuadCurve(to: CGPoint(x: bottomEllipse.maxX, y: bottomEllipse.midY), control: CGPoint(x: bottomEllipse.maxX, y: bottomEllipse.maxY))
                context.fillPath()
                context.fill(CGRect(origin: CGPoint(x: fixedMainDiameter / 2.0, y: floor(fixedMainDiameter / 2.0)),
                                    size: CGSize(width: fixedMainDiameter / 2.0, height: ceil(bottomEllipse.midY) - floor(fixedMainDiameter / 2.0))))
                // Square off the body corner under the tail so the bottom edge
                // runs flat into it instead of dipping where corner and curve meet.
                context.fill(CGRect(x: fixedMainDiameter - bottomRightRadius, y: fixedMainDiameter - bottomRightRadius,
                                    width: bottomRightRadius, height: bottomRightRadius))
            }

            if drawTail {
                // Punch the concave tail curve out of the fill.
                context.setFillColor(UIColor.clear.cgColor)
                context.setBlendMode(.copy)
                context.fillEllipse(in: topEllipse.insetBy(dx: borderOffset, dy: borderOffset))
                context.setBlendMode(.normal)
            }

            // Outline (stroke).
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(borderWidth)
            if drawTail {
                // Stroking the rounded rect and the tail curves separately left
                // their inner parts visible inside the filled bubble as a grey
                // arc. Stroke the body everywhere except the tail corner, then
                // trace only the outer edge of the merged body + tail shape.
                let cornerStart = fixedMainDiameter - bottomRightRadius
                context.saveGState()
                context.addRect(CGRect(x: -10.0, y: -10.0, width: fixedMainDiameter + 40.0, height: fixedMainDiameter + 40.0))
                context.addRect(CGRect(x: cornerStart, y: cornerStart, width: 40.0, height: 40.0))
                context.clip(using: .evenOdd)
                addBubblePath(offset: borderOffset)
                context.strokePath()
                context.restoreGState()

                context.addPath(tailOutlinePath(bottomEllipse: bottomEllipse, topEllipse: topEllipse,
                                                bodyEdge: fixedMainDiameter, cornerRadius: bottomRightRadius))
                context.strokePath()
            } else {
                addBubblePath(offset: borderOffset)
                context.strokePath()
            }
        }

        // Telegram's stretch points: outgoing (18, 19); incoming mirrored (24, 19).
        let outX = Int(additionalInset + strokeInset + round(fixedMainDiameter / 2.0)) - 1
        let outY = Int(additionalInset + strokeInset + round(fixedMainDiameter / 2.0))
        let capX = incoming ? (Int(sourceRawSize.width) - outX + Int(additionalInset)) : outX
        let capY = outY
        let insets = UIEdgeInsets(top: CGFloat(capY),
                                  left: CGFloat(capX),
                                  bottom: imageSize.height - CGFloat(capY) - 1.0,
                                  right: imageSize.width - CGFloat(capX) - 1.0)
        return image.resizableImage(withCapInsets: insets, resizingMode: .stretch)
    }

    /// Outer edge of the tail corner in the 33pt template (outgoing orientation):
    /// body right edge down to the punched ellipse, the ellipse down to the tip,
    /// then the lower tail curve back to the body and along its flat bottom.
    private static func tailOutlinePath(bottomEllipse: CGRect, topEllipse: CGRect,
                                        bodyEdge: CGFloat, cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let cornerCenter = CGPoint(x: bodyEdge - cornerRadius, y: bodyEdge - cornerRadius)
        let steps = 24

        path.move(to: CGPoint(x: bodyEdge, y: cornerCenter.y))
        path.addLine(to: CGPoint(x: bodyEdge, y: topEllipse.midY))

        let rx = topEllipse.width / 2.0, ry = topEllipse.height / 2.0
        let endAngle = CGFloat.pi - asin(min(1.0, (bodyEdge - topEllipse.midY) / ry))
        for i in 1...steps {
            let angle = CGFloat.pi + (endAngle - CGFloat.pi) * CGFloat(i) / CGFloat(steps)
            path.addLine(to: CGPoint(x: topEllipse.midX + rx * cos(angle), y: topEllipse.midY + ry * sin(angle)))
        }

        let p0 = CGPoint(x: bottomEllipse.minX, y: bottomEllipse.midY)
        let c = CGPoint(x: bottomEllipse.minX, y: bottomEllipse.maxY)
        let p2 = CGPoint(x: bottomEllipse.midX, y: bottomEllipse.maxY)
        func quad(_ t: CGFloat) -> CGPoint {
            CGPoint(x: (1 - t) * (1 - t) * p0.x + 2 * t * (1 - t) * c.x + t * t * p2.x,
                    y: (1 - t) * (1 - t) * p0.y + 2 * t * (1 - t) * c.y + t * t * p2.y)
        }
        // Walk the lower curve back from the tip to the body edge; the squared
        // corner under the tail continues it as a flat bottom edge.
        var exitT: CGFloat = 0
        var t: CGFloat = 1
        while t > 0 {
            if quad(t).x <= bodyEdge {
                exitT = t
                break
            }
            t -= 0.001
        }
        for i in 0...steps {
            path.addLine(to: quad(1 - (1 - exitT) * CGFloat(i) / CGFloat(steps)))
        }
        path.addLine(to: CGPoint(x: cornerCenter.x, y: bodyEdge))
        return path
    }

    /// Distance from the bubble image's edges to the visual bubble body.
    /// (additionalInset + strokeInset = 2pt on three sides, +6pt tail zone on the tail side.)
    static let bubbleImageBodyInset: CGFloat = 2.0
    static let bubbleImageTailInset: CGFloat = 8.0

    // MARK: - Checkmarks
    // Transcribed from PresentationThemeEssentialGraphics.swift generateCheckImage(partial:color:width:).

    static func checkImage(partial: Bool, color: UIColor, width: CGFloat = 11.0) -> UIImage {
        let size = CGSize(width: width, height: floor(width * 9.0 / 11.0))
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            context.scaleBy(x: width / 11.0, y: width / 11.0)
            context.translateBy(x: 1.0, y: 1.0)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(0.99)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            let path = CGMutablePath()
            if partial {
                path.move(to: CGPoint(x: 0.5, y: 7.0))
                path.addLine(to: CGPoint(x: 7.0, y: 0.0))
            } else {
                path.move(to: CGPoint(x: 0.0, y: 4.0))
                path.addLine(to: CGPoint(x: 2.95157047, y: 6.95157047))
                path.addCurve(to: CGPoint(x: 3.04490857, y: 6.95157047),
                              control1: CGPoint(x: 2.97734507, y: 6.97734507),
                              control2: CGPoint(x: 3.01913396, y: 6.97734507))
                path.addCurve(to: CGPoint(x: 3.04660389, y: 6.9498112),
                              control1: CGPoint(x: 3.04548448, y: 6.95099456),
                              control2: CGPoint(x: 3.04604969, y: 6.95040803))
                path.addLine(to: CGPoint(x: 9.5, y: 0.0))
            }
            context.addPath(path)
            context.strokePath()
        }
    }

    // MARK: - Glass back chevron
    // Transcribed from NavigationBarImpl/Sources/NavigationButtonNode.swift glassBackArrowImage.

    static let glassBackArrowImage: UIImage = {
        let imageSize = CGSize(width: 44.0, height: 44.0)
        let topRightPoint = CGPoint(x: 24.6, y: 14.0)
        let centerPoint = CGPoint(x: 17.0, y: imageSize.height * 0.5)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        return UIGraphicsImageRenderer(size: imageSize, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(2.0)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.move(to: topRightPoint)
            context.addLine(to: centerPoint)
            context.addLine(to: CGPoint(x: topRightPoint.x, y: imageSize.height - topRightPoint.y))
            context.strokePath()
        }.withRenderingMode(.alwaysTemplate)
    }()
}
