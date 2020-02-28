//
//  SegmentedGaugeBarView.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 3/22/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit


public protocol SegmentedGaugeBarViewDelegate: AnyObject {
    /// Invoked only when `progress` is updated via gesture.
    func segmentedGaugeBarView(_ view: SegmentedGaugeBarView, didUpdateProgressFrom oldValue: Double, to newValue: Double)
}

@IBDesignable
public class SegmentedGaugeBarView: UIView {
    @IBInspectable
    public var numberOfSegments: Int {
        get {
            return gaugeLayer.numberOfSegments
        }
        set {
            gaugeLayer.numberOfSegments = newValue
        }
    }

    @IBInspectable
    public var startColor: UIColor {
        get {
            return UIColor(cgColor: gaugeLayer.startColor)
        }
        set {
            gaugeLayer.startColor = newValue.cgColor
        }
    }

    @IBInspectable
    public var endColor: UIColor {
        get {
            return UIColor(cgColor: gaugeLayer.endColor)
        }
        set {
            gaugeLayer.endColor = newValue.cgColor
        }
    }

    @IBInspectable
    public var borderWidth: CGFloat {
        get {
            return gaugeLayer.gaugeBorderWidth
        }
        set {
            gaugeLayer.gaugeBorderWidth = newValue
        }
    }

    @IBInspectable
    public var borderColor: UIColor {
        get {
            return UIColor(cgColor: gaugeLayer.gaugeBorderColor)
        }
        set {
            gaugeLayer.gaugeBorderColor = newValue.cgColor
        }
    }

    @IBInspectable
    public var progress: Double {
        get {
            if displaysThumb {
                return Double(fractionThrough(thumb.center.x, in: thumbCenterXRange))
            } else {
                return visualProgress
            }
        }
        set {
            if displaysThumb {
                thumb.center.x = interpolatedValue(at: CGFloat(newValue), through: thumbCenterXRange).clamped(to: thumbCenterXRange)
                // Push the gauge progress behind the thumb, ensuring the cap rounding is not visible.
                let gaugeX = thumb.center.x + 0.25 * thumb.frame.width
                visualProgress = newValue == 0 ? 0 : Double(fractionThrough(gaugeX, in: gaugeXRange))
            } else {
                visualProgress = newValue
            }
        }
    }

    private var visualProgress: Double {
        get { Double(gaugeLayer.progress) }
        set { gaugeLayer.progress = CGFloat(newValue) }
    }

    public weak var delegate: SegmentedGaugeBarViewDelegate?

    override public class var layerClass: AnyClass {
        return SegmentedGaugeBarLayer.self
    }

    private var gaugeLayer: SegmentedGaugeBarLayer {
        return layer as! SegmentedGaugeBarLayer
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupPanGestureRecognizer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPanGestureRecognizer()
    }

    private lazy var thumb = ThumbView()

    public var displaysThumb = false {
        didSet {
            if displaysThumb {
                assert(numberOfSegments == 1, "Thumb only supported for single-segment gauges")
                if thumb.superview == nil {
                    addSubview(thumb)
                }
            } else {
                thumb.removeFromSuperview()
            }
        }
    }

    private var panGestureRecognizer: UIPanGestureRecognizer?

    private func setupPanGestureRecognizer() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGestureRecognizer = pan
        addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            guard recognizer.numberOfTouches == 1 else {
                break
            }

            let location = recognizer.location(ofTouch: 0, in: self)
            let gaugeFillFraction = fractionThrough(location.x, in: gaugeXRange)
            let oldValue = progress
            let newValue = (Double(gaugeFillFraction) * Double(numberOfSegments)).clamped(to: 0...Double(numberOfSegments))
            CATransaction.withoutActions {
                progress = newValue
            }

            delegate?.segmentedGaugeBarView(self, didUpdateProgressFrom: oldValue, to: newValue)
        case .ended:
            uglyWorkaroundToForceRedraw()
        default:
            break
        }
    }

    private func uglyWorkaroundToForceRedraw() {
        // Resolves an issue--most of the time--where dragging _very_ rapidly then releasing
        // can cause the gauge layer to fall behind a cycle in rendering.
        // - `setNeedsDisplay()` is insufficient.
        // - Adding additional executions (delay times) catches the issue with a greater probability,
        //   with diminishing returns after four executions (by observation).
        for (index, delayMS) in [10, 25, 50, 100].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMS)) {
                CATransaction.withoutActions {
                    self.progress = index % 2 == 0 ? self.progress.nextUp : self.progress.nextDown
                }
            }
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.height / 2

        updateThumbPosition()
    }

    private var gaugeXRange: ClosedRange<CGFloat> {
        (bounds.minX + 2 * borderWidth)...(bounds.maxX - 2 * borderWidth)
    }

    private var thumbCenterXRange: ClosedRange<CGFloat> {
        let radius = thumb.bounds.width / 2
        return (gaugeXRange.lowerBound + radius)...(gaugeXRange.upperBound - radius)
    }

    private func updateThumbPosition() {
        guard displaysThumb else {
            return
        }

        let diameter = bounds.height - 2 * borderWidth
        thumb.bounds.size = CGSize(width: diameter, height: diameter)
        let xPosition = interpolatedValue(at: CGFloat(progress), through: thumbCenterXRange)
        thumb.center = CGPoint(x: xPosition, y: bounds.midY)
    }

    public func cancelActiveTouches() {
        guard panGestureRecognizer?.isEnabled == true else {
            return
        }

        panGestureRecognizer?.isEnabled = false
        panGestureRecognizer?.isEnabled = true
    }
}

fileprivate extension CATransaction {
    static func withoutActions(_ execute: () -> Void) {
        begin()
        setValue(true, forKey: kCATransactionDisableActions)
        execute()
        commit()
    }
}
