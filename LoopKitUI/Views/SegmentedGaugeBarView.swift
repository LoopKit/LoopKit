//
//  SegmentedGaugeBarView.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 3/22/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit

@IBDesignable
class SegmentedGaugeBarView: UIView {
    @IBInspectable
    var numberOfSegments: Int {
        get {
            return gaugeLayer.numberOfSegments
        }
        set {
            gaugeLayer.numberOfSegments = newValue
        }
    }

    @IBInspectable
    var startColor: UIColor {
        get {
            return UIColor(cgColor: gaugeLayer.startColor)
        }
        set {
            gaugeLayer.startColor = newValue.cgColor
        }
    }

    @IBInspectable
    var endColor: UIColor {
        get {
            return UIColor(cgColor: gaugeLayer.endColor)
        }
        set {
            gaugeLayer.endColor = newValue.cgColor
        }
    }

    @IBInspectable
    var borderWidth: CGFloat {
        get {
            return gaugeLayer.gaugeBorderWidth
        }
        set {
            gaugeLayer.gaugeBorderWidth = newValue
        }
    }

    @IBInspectable
    var borderColor: UIColor {
        get {
            return UIColor(cgColor: gaugeLayer.gaugeBorderColor)
        }
        set {
            gaugeLayer.gaugeBorderColor = newValue.cgColor
        }
    }

    @IBInspectable
    var progress: Double {
        get {
            return Double(gaugeLayer.progress)
        }
        set {
            return gaugeLayer.progress = CGFloat(newValue)
        }
    }

    override class var layerClass: AnyClass {
        return SegmentedGaugeBarLayer.self
    }

    private var gaugeLayer: SegmentedGaugeBarLayer {
        return layer as! SegmentedGaugeBarLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.height / 2
    }
}
