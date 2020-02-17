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
            return Double(gaugeLayer.progress)
        }
        set {
            gaugeLayer.progress = CGFloat(newValue)
        }
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

    private func setupPanGestureRecognizer() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            let location = recognizer.location(ofTouch: 0, in: self)
            let fractionThrough = Double(location.x / frame.width)
            let oldValue = progress
            progress = (fractionThrough * Double(numberOfSegments)).clamped(to: 0...Double(numberOfSegments))
            delegate?.segmentedGaugeBarView(self, didUpdateProgressFrom: oldValue, to: progress)
        default:
            break
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.height / 2
    }
}
