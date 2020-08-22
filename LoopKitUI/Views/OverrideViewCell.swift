//
//  OverrideViewCell.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 8/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct OverrideViewCell: View {
    static let symbolWidth: CGFloat = 40
    
    var symbolLabel: Text
    var nameLabel: Text
    var targetRangeLabel: Text
    var durationLabel: Text
    var subtitleLabel: Text
    var insulinNeedsScaleFactor: Double?
    
    public init(
        symbol: Text,
        name: Text,
        targetRange: Text,
        duration: Text,
        subtitle: Text,
        insulinNeedsScaleFactor: Double?
    ) {
        self.symbolLabel = symbol
        self.nameLabel = name
        self.targetRangeLabel = targetRange
        self.durationLabel = duration
        self.subtitleLabel = subtitle
        self.insulinNeedsScaleFactor = insulinNeedsScaleFactor
    }

    public var body: some View {
        HStack {
            symbolLabel
            .font(.largeTitle)
            .frame(width: Self.symbolWidth) // for alignment
            VStack(alignment: .leading, spacing: 3) {
                nameLabel
                targetRangeLabel
                .font(.caption)
                .foregroundColor(Color.gray)
                if self.insulinNeedsScaleFactor != nil {
                    insulinNeedsBar
                }
            }
            Spacer()
            VStack {
                HStack(spacing: 4) {
                    timer
                    durationLabel
                    .font(.caption)
                }
                .foregroundColor(Color.gray)
                subtitleLabel
                .font(.caption)
            }
        }
        .frame(minHeight: 53)
    }
    
    private var insulinNeedsBar: some View {
        GeometryReader { geo in
            HStack {
                Group {
                    if self.insulinNeedsScaleFactor != nil {
                        SegmentedGaugeBar(insulinNeedsScaler: self.insulinNeedsScaleFactor!)
                        .frame(minHeight: 12)
                    }
                }
                Spacer(minLength: geo.size.width * 0.35) // Hack to fix spacing
            }
        }
    }

    var timer: some View {
        Image(systemName: "timer")
        .resizable()
        .frame(width: 12.0, height: 12.0)
    }
}

struct SegmentedGaugeBar: UIViewRepresentable {
    var insulinNeedsScaler: Double
    
    init(insulinNeedsScaler: Double) {
        self.insulinNeedsScaler = insulinNeedsScaler
    }
    
    func makeUIView(context: Context) -> SegmentedGaugeBarView {
        let view = SegmentedGaugeBarView()
        view.backgroundColor = .white
        view.numberOfSegments = 2
        view.startColor = UIColor.lightenedInsulin!
        view.endColor = UIColor.darkenedInsulin!
        view.borderWidth = 1
        view.borderColor = .systemGray
        view.progress = insulinNeedsScaler
        return view
    }
    
    func updateUIView(_ view: SegmentedGaugeBarView, context: Context) { }
}
