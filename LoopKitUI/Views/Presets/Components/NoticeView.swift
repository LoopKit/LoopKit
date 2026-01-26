//
//  NoticeView.swift
//  Loop
//
//  Created by Pete Schwamb on 5/23/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//
import SwiftUI

public struct NoticeView: View {
    var title: Text
    var caption: Text

    public init(title: Text, caption: Text) {
        self.title = title
        self.caption = caption
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    title
                        .font(Font(UIFont.preferredFont(forTextStyle: .title3)))
                        .bold()
                        .fixedSize(horizontal: false, vertical: true)
                }

                caption
                    .font(.callout)
                    .foregroundColor(Color(.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Spacer()
        }
        .padding(.vertical, 8)
    }
}
