//
//  CardStack.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/16/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct CardStack: View {
    var cards: [Card?]
    var spacing: CGFloat?
    
    public init(cards: [Card?]) {
        self.cards = cards
        self.spacing = nil
    }

    public var body: some View {
        VStack(spacing: spacing) {
            ForEach(self.cards.indices, id: \.self) { index in
                self.cards[index]
            }
        }
    }
}

extension CardStack {
    init(reducing stacks: [CardStack]) {
        self.cards = stacks.flatMap { $0.cards }
        self.spacing = nil
    }
}

extension CardStack {
    private init(_ other: Self, spacing: CGFloat? = nil) {
        self.cards = other.cards
        self.spacing = spacing ?? other.spacing
    }

    func spacing(_ spacing: CGFloat?) -> Self { Self(self, spacing: spacing) }
}
