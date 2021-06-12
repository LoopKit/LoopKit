//
//  CardList.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct CardListSection: View {
    var title: Text?
    var stack: CardStack

    public init(title: Text? = nil, @CardStackBuilder cards: () -> CardStack) {
        self.title = title
        self.stack = cards()
    }

    public var body: some View {
        VStack(spacing: 6) {
            if let title = title {
                HStack {
                    title
                        .font(Font(UIFont.preferredFont(forTextStyle: .title3)))
                        .bold()
                    Spacer()
                }
                .padding(.leading)
            }
            stack
        }
    }
}

public enum CardListStyle {
    case simple(CardStack)
    case sectioned([CardListSection])
}

/// Displays a list of cards similar to a `List` with an inset grouped style,
/// but without the baggage of `UITableViewCell` resizing, enabling cells to expand smoothly.
public struct CardList<Trailer: View>: View {
    var title: Text?
    var style: CardListStyle
    var trailer: Trailer?
    
    public init(title: Text? = nil, style: CardListStyle, trailer: Trailer) {
        self.title = title
        self.style = style
        self.trailer = trailer
    }

    public init(title: Text? = nil, style: CardListStyle) where Trailer == EmptyView {
        self.title = title
        self.style = style
        self.trailer = nil
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                titleText
                    .fixedSize(horizontal: false, vertical: true)

                cards
                if let trailer = trailer {
                    trailer
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var titleText: some View {
        if let title = title {
            HStack {
                title
                    .font(.largeTitle)
                    .bold()
                Spacer()
            }
            .padding()
            .padding(.bottom, 4)
            .background(Color(.systemGroupedBackground))
        } else {
            Spacer()
        }
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
