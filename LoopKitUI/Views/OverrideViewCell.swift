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
        Section {
            HStack {
                symbolLabel
                .font(.largeTitle)
                .frame(width: Self.symbolWidth) // for alignment
                VStack(alignment: .leading) {
                    nameLabel
                    targetRangeLabel
                    .font(.caption)
                    .foregroundColor(Color.gray)
                    insulinNeedsBarIfNeeded
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
        }
    }
    
    private var insulinNeedsBarIfNeeded: some View {
        Group {
            if insulinNeedsScaleFactor != nil {
                GeometryReader { geo in
                    SegmentedGaugeBar(insulinNeedsScaler: self.insulinNeedsScaleFactor!)
                    // ANNA TODO: fix alignment
                    .frame(maxWidth: geo.size.width / 2, minHeight: 12)
                }
                
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
        view.startColor = UIColor.orange
        view.endColor = UIColor.red
        view.borderWidth = 1
        view.borderColor = .systemGray
        view.progress = insulinNeedsScaler
        return view
    }
    
    func updateUIView(_ view: SegmentedGaugeBarView, context: Context) {
       
    }
}
