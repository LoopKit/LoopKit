//
//  OverrideViewCell.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 8/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct OverrideViewCell: View {
    var symbolLabel: Text
    var startTimeLabel: Text
    var nameLabel: Text
    var targetRangeLabel: Text
    // var insulinNeedsBar
    var durationLabel: Text
    
    public init(
        symbol: Text,
        startTime: Text,
        name: Text,
        targetRange: Text,
        duration: Text
    ) {
        symbolLabel = symbol
        startTimeLabel = startTime
        nameLabel = name
        targetRangeLabel = targetRange
        durationLabel = duration
    }

    public var body: some View {
        Section {
            HStack {
                symbolLabel
                .font(.title)
                VStack (alignment: .leading) {
                    nameLabel
                    targetRangeLabel
                    .font(.caption)
                    .foregroundColor(Color.gray)
                    // insulinNeedsBar
                }
                Spacer()
                VStack {
                    HStack(spacing: 4) {
                        timer
                        durationLabel
                        .font(.caption)
                    }
                    .foregroundColor(Color.gray)
                    scheduleButton
                }

            }
        }
    }

    var timer: some View {
        Image(systemName: "timer")
        .resizable()
        .frame(width: 12.0, height: 12.0)
    }

    var scheduleButton: some View {
        Button(action: {
            print("Anna TODO")
        }) {
            Image(systemName: "calendar")
            .resizable()
            .frame(width: 20.0, height: 20.0)
        }
    }
}

struct OverrideSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        OverrideViewCell(symbol: Text("⚾️"), startTime: Text("TODO"), name: Text("Baseball"), targetRange: Text("100-100"), duration: Text("1h"))
    }
}
