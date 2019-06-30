//
//  SegmentedGaugeBarLayer.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 3/22/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit


class SegmentedGaugeBarLayer: CALayer {

    var numberOfSegments = 1 {
        didSet {
            setNeedsDisplay()
        }
    }

    var startColor = UIColor.white.cgColor {
        didSet {
            setNeedsDisplay()
        }
    }

    var endColor = UIColor.black.cgColor {
        didSet {
            setNeedsDisplay()
        }
    }

    var gaugeBorderWidth: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }

    var gaugeBorderColor = UIColor.black.cgColor {
        didSet {
            setNeedsDisplay()
        }
    }

    @NSManaged var progress: CGFloat

    override class func needsDisplay(forKey key: String) -> Bool {
        return key == #keyPath(SegmentedGaugeBarLayer.progress)
            || super.needsDisplay(forKey: key)
    }

    override func action(forKey event: String) -> CAAction? {
        if event == #keyPath(progress) {
            let animation = CABasicAnimation(keyPath: event)
            animation.fromValue = presentation()?.progress
            return animation
        } else {
            return super.action(forKey: event)
        }
    }

    override func display() {
        contents = contentImage()
    }

    private func contentImage() -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let uiImage = renderer.image { context in
            drawGauge(in: context.cgContext)
        }
        return uiImage.cgImage
    }

    private func drawGauge(in context: CGContext) {
        var previousSegmentBorder: (path: UIBezierPath, color: CGColor)?

        func finishPreviousSegment() {
            if let (borderPath, borderColor) = previousSegmentBorder {
                drawBorder(borderPath, color: borderColor, in: context)
            }
        }

        let segmentCounts = 1...numberOfSegments
        for countFromRight in segmentCounts {
            let isRightmostSegment = countFromRight == segmentCounts.lowerBound
            let isLeftmostSegment = countFromRight == segmentCounts.upperBound

            let fillFraction = (presentationProgress - CGFloat(numberOfSegments - countFromRight)).clamped(to: 0...1)

            let (segmentSize, roundedCorners): (CGSize, UIRectCorner) = {
                if isLeftmostSegment {
                    return (leftmostSegmentSize, .allCorners)
                } else {
                    return (normalSegmentSize, [.topRight, .bottomRight])
                }
            }()

            var originX = bounds.width - gaugeBorderWidth / 2 - CGFloat(countFromRight) * leftmostSegmentSize.width
            if !isLeftmostSegment {
                originX -= segmentOverlap
            }
            let segmentOrigin = CGPoint(x: originX, y: bounds.minY + gaugeBorderWidth / 2)
            let segmentRect = CGRect(origin: segmentOrigin, size: segmentSize)

            if !isRightmostSegment {
                drawOverlapInset(for: segmentRect, in: context)
                finishPreviousSegment()
            }

            let borderPath = UIBezierPath(roundedRect: segmentRect, byRoundingCorners: roundedCorners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
            let borderColor = fillFraction > 0
                ? gaugeBorderColor
                : UIColor(cgColor: gaugeBorderColor).withAlphaComponent(0.5).cgColor

            clearSegmentArea(tracedBy: borderPath, in: context)
            previousSegmentBorder = (path: borderPath, color: borderColor)

            guard fillFraction > 0 else {
                continue
            }

            var segmentFillRect = CGRect(origin: segmentOrigin, size: leftmostSegmentSize).insetBy(dx: fillInset, dy: fillInset)
            segmentFillRect.size.width *= fillFraction
            if !isLeftmostSegment {
                segmentFillRect.size.width += segmentOverlap
            }

            drawFilledGradient(over: segmentFillRect, roundingCorners: roundedCorners, in: context)
        }

        finishPreviousSegment()
    }

    private var fillInset: CGFloat {
        return 1.5 * gaugeBorderWidth
    }

    private var segmentOverlap: CGFloat {
        return cornerRadius
    }

    private var presentationProgress: CGFloat {
        return presentation()?.progress ?? self.progress
    }

    private var leftmostSegmentSize: CGSize {
        return CGSize(
            width: (bounds.width - gaugeBorderWidth) / CGFloat(numberOfSegments),
            height: bounds.height - gaugeBorderWidth
        )
    }

    private var normalSegmentSize: CGSize {
        return CGSize(
            width: leftmostSegmentSize.width + segmentOverlap,
            height: leftmostSegmentSize.height
        )
    }

    private func clearSegmentArea(tracedBy path: UIBezierPath, in context: CGContext) {
        context.addPath(path.cgPath)
        context.setFillColor(backgroundColor ?? UIColor.white.cgColor)
        context.fillPath()
    }

    private func drawFilledGradient(over rect: CGRect, roundingCorners roundedCorners: UIRectCorner, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: roundedCorners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
        context.addPath(path.cgPath)
        context.clip()

        let pathBounds = path.bounds
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [gradientColor(atX: pathBounds.minX),
                     gradientColor(atX: pathBounds.maxX)] as CFArray,
            locations: [0, 1]
        )!

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: pathBounds.minX, y: pathBounds.midY),
            end: CGPoint(x: pathBounds.maxX, y: pathBounds.midY),
            options: []
        )
    }

    private func drawOverlapInset(for segmentRect: CGRect, in context: CGContext) {
        var overlapInsetRect = segmentRect
        overlapInsetRect.size.width += gaugeBorderWidth
        let path = UIBezierPath(roundedRect: overlapInsetRect, cornerRadius: cornerRadius)
        context.setStrokeColor(backgroundColor ?? UIColor.white.cgColor)
        context.setLineWidth(gaugeBorderWidth)
        context.setFillColor(backgroundColor ?? UIColor.white.cgColor)
        context.addPath(path.cgPath)
        context.drawPath(using: .fillStroke)
    }

    private func drawBorder(_ path: UIBezierPath, color: CGColor, in context: CGContext) {
        context.addPath(path.cgPath)
        context.setLineWidth(gaugeBorderWidth)
        context.setStrokeColor(color)
        context.strokePath()
    }

    private func gradientColor(atX x: CGFloat) -> CGColor {
        return UIColor.interpolatingBetween(
            UIColor(cgColor: startColor),
            UIColor(cgColor: endColor),
            biasTowardSecondColor: fractionThrough(x, in: bounds.minX...bounds.maxX)
        ).cgColor
    }
}
