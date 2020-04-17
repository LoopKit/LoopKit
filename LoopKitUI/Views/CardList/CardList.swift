//
//  CardList.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


/// Displays a list of cards similar to a `List` with an inset grouped style,
/// but without the baggage of `UITableViewCell` resizing, enabling cells to expand smoothly.
struct CardList: View {
    var title: Text
    var stack: CardStack
    var spacing: CGFloat

    init(title: Text, spacing: CGFloat = 8, content: CardStack) {
        self.title = title
        self.spacing = spacing
        self.stack = content
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                titleText

                VStack(spacing: self.spacing) {
                    ForEach(self.stack.cards.indices, id: \.self) { index in
                        self.stack.cards[index]
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var titleText: some View {
        HStack {
            title
                .font(.largeTitle)
                .bold()
            Spacer()
        }
        .padding()
        .padding(.bottom, 4)
        .background(Color(.systemGroupedBackground))
    }
}
