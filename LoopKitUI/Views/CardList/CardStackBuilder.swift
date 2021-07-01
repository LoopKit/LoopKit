//
//  CardStackBuilder.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


/// Constructs an array of `Card` views from arbitrary `View` instances.
///
/// A multi-component card can be constructed using one of `Card`'s initializers.
@resultBuilder
public struct CardStackBuilder {
    public typealias Component = CardStack

    public static func buildIf(_ component: Component?) -> Component {
        // If `nil` (i.e. a condition is `false`), leave a placeholder `nil` view to enable smooth insertion when the condition becomes `true`.
        component ?? CardStack(cards: [nil])
    }
    
    public static func buildBlock<V: View>(_ v: V) -> Component {
        toCardStack(v)
    }

    public static func buildBlock<V0: View, V1: View>(_ v0: V0, _ v1: V1) -> Component {
        CardStack(reducing: [toCardStack(v0), toCardStack(v1)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View>(_ v0: V0, _ v1: V1, _ v2: V2) -> Component {
        CardStack(reducing: [toCardStack(v0), toCardStack(v1), toCardStack(v2)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3) -> Component {
        CardStack(reducing: [toCardStack(v0), toCardStack(v1), toCardStack(v2), toCardStack(v3)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4) -> Component {
        CardStack(reducing: [toCardStack(v0), toCardStack(v1), toCardStack(v2), toCardStack(v3), toCardStack(v4)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5) -> Component {
        CardStack(reducing: [toCardStack(v0), toCardStack(v1), toCardStack(v2), toCardStack(v3), toCardStack(v4), toCardStack(v5)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6) -> Component {
        CardStack(reducing: [toCardStack(v0), toCardStack(v1), toCardStack(v2), toCardStack(v3), toCardStack(v4), toCardStack(v5), toCardStack(v6)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7) -> Component {
        CardStack(reducing: [toCardStack(v0), toCardStack(v1), toCardStack(v2), toCardStack(v3), toCardStack(v4), toCardStack(v5), toCardStack(v6), toCardStack(v7)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8) -> Component {
        CardStack(reducing: [toCardStack(v0), toCardStack(v1), toCardStack(v2), toCardStack(v3), toCardStack(v4), toCardStack(v5), toCardStack(v6), toCardStack(v7), toCardStack(v8)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9) -> Component {
        CardStack(reducing: [toCardStack(v0), toCardStack(v1), toCardStack(v2), toCardStack(v3), toCardStack(v4), toCardStack(v5), toCardStack(v6), toCardStack(v7), toCardStack(v8), toCardStack(v9)])
    }

    // TODO: Simplify using `buildExpression` when Swift 5.2 is available.
    private static func toCardStack<V: View>(_ v: V) -> CardStack {
        if let stack = v as? CardStack {
            return stack
        } else if let card = v as? Card {
            return CardStack(cards: [card])
        } else {
            return CardStack(cards: [Card(parts: [AnyView(v)])])
        }
    }
}
