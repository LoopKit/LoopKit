//
//  CardList.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct CardListSection: View {
    var title: Text
    var stack: CardStack

    public init(title: Text, @CardStackBuilder cards: () -> CardStack) {
        self.title = title
        self.stack = cards()
    }

    public var body: some View {
        VStack(spacing: 6) {
            HStack {
                title
                    .font(Font(UIFont.preferredFont(forTextStyle: .title3)))
                    .bold()
                Spacer()
            }
            .padding(.leading)

            stack
        }
    }
}


/// Displays a list of cards similar to a `List` with an inset grouped style,
/// but without the baggage of `UITableViewCell` resizing, enabling cells to expand smoothly.
struct CardList: View {
    enum Style {
        case simple(CardStack)
        case sectioned([CardListSection])
    }

    var title: Text
    var style: Style

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                titleText
                    .fixedSize(horizontal: false, vertical: true)

                cards
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

    private var cards: some View {
        switch style {
        case .simple(let stack):
            return AnyView(stack)
        case .sectioned(let sections):
            return AnyView(
                VStack(spacing: 16) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                        section
                    }
                }
            )
        }
    }
}
