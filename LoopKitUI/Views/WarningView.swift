//
//  WarningView.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public enum WarningSeverity: Int, Comparable {
    case `default`
    case critical

    public static func < (lhs: WarningSeverity, rhs: WarningSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct WarningView: View {
    @Environment(\.guidanceColors) var guidanceColors
    var title: Text
    var caption: Text
    var severity: WarningSeverity

    public init(title: Text, caption: Text, severity: WarningSeverity = .default) {
        self.title = title
        self.caption = caption
        self.severity = severity
    }

    public var body: some View {
        HStack {
              VStack(alignment: .leading) {
                  HStack(alignment: .center) {
                      Image(systemName: "exclamationmark.triangle.fill")
                          .foregroundColor(warningColor)

                      title
                          .font(Font(UIFont.preferredFont(forTextStyle: .title3)))
                          .bold()
                          .fixedSize(horizontal: false, vertical: true)
                          .animation(nil)
                  }
                  .padding(.bottom, 2)

                  caption
                      .font(.callout)
                      .foregroundColor(Color(.secondaryLabel))
                      .fixedSize(horizontal: false, vertical: true)
                      .animation(nil)
              }
              .accessibilityElement(children: .combine)

              Spacer()
          }
    }

    private var warningColor: Color {
        switch severity {
        case .default:
            return guidanceColors.warning
        case .critical:
            return guidanceColors.critical
        }
    }
}
