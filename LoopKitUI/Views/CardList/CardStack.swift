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

    public var body: some View {
        VStack {
            ForEach(self.cards.indices, id: \.self) { index in
                self.cards[index]
            }
        }
    }
}

extension CardStack {
    init(reducing stacks: [CardStack]) {
        cards = stacks.flatMap { $0.cards }
    }
}
