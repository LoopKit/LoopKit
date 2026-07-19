//
//  StatusChartHighlightLayer.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit


/// The touch-interaction state of a chart, driven by an external `UIGestureRecognizer`
/// and observed by the hosted Swift Charts view to draw the highlight overlay.
final class ChartHighlightModel: ObservableObject {
    /// The gesture's location in the hosted chart view's coordinate space, or nil when inactive
    @Published var touchLocation: CGPoint?
}


/// Connects an externally-owned gesture recognizer (long-press on the table view or chart
/// container) to a hosted chart's highlight model, translating touches into chart-local
/// coordinates. Each chart in a stack listens to the same recognizer, so touching one chart
/// highlights the matching time across all of them, as with the previous SwiftCharts layers.
final class ChartGestureBridge: NSObject {
    let model = ChartHighlightModel()

    private weak var hostView: UIView?
    private weak var gestureRecognizer: UIGestureRecognizer?

    func attach(to gestureRecognizer: UIGestureRecognizer?, hostView: UIView) {
        self.hostView = hostView

        if let oldRecognizer = self.gestureRecognizer, oldRecognizer !== gestureRecognizer {
            oldRecognizer.removeTarget(self, action: nil)
        }

        guard let gestureRecognizer = gestureRecognizer else {
            self.gestureRecognizer = nil
            return
        }

        if self.gestureRecognizer !== gestureRecognizer {
            gestureRecognizer.addTarget(self, action: #selector(handleGesture(_:)))
            self.gestureRecognizer = gestureRecognizer
        }
    }

    @objc private func handleGesture(_ recognizer: UIGestureRecognizer) {
        guard let hostView = hostView, hostView.window != nil else {
            return
        }

        switch recognizer.state {
        case .began, .changed:
            model.touchLocation = recognizer.location(in: hostView)
        case .ended, .cancelled, .failed, .possible:
            model.touchLocation = nil
        @unknown default:
            model.touchLocation = nil
        }
    }
}


/// The data a chart exposes for the touch-highlight overlay
struct ChartHighlightSpec {
    static let defaultPointSize: CGFloat = 16

    /// Candidate points, ordered by date; the point nearest the touch's x-position is highlighted
    let points: [ChartPoint]

    /// The color of the highlight dot and value label, unless a point overrides it
    let tintColor: UIColor

    /// Vertical offset applied to the highlight dot (e.g. carb markers drawn above the axis)
    var highlightPointOffsetY: CGFloat = 0
}


enum ChartHosting {
    /// Wraps a SwiftUI chart in a plain UIView for display inside `ChartContainerView`.
    ///
    /// Chart generation is always initiated from UIKit layout on the main thread.
    static func view<Content: View>(frame: CGRect, rootView: Content) -> UIView {
        return MainActor.assumeIsolated {
            let contentView = UIHostingConfiguration { rootView }
                .margins(.all, 0)
                .makeContentView()
            contentView.frame = frame
            contentView.backgroundColor = .clear
            return contentView
        }
    }
}
