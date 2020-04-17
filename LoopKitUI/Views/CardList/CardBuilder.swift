//
//  CardBuilder.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


/// A function builder designed to construct a `Card`.
///
/// Transformations are applied as follows:
/// - An expression conforming to `View` becomes one component of one card.
/// - An instance of `Splat` is unrolled into a dynamic number of components within one card.
///
/// Any number of components (individual or splatted) can be sequenced and combined into a single card.
@_functionBuilder
public struct CardBuilder {
    public typealias Component = Card

    public static func buildIf(_ component: Component?) -> Component {
        // If `nil` (i.e. a condition is `false`), leave a placeholder `nil` view to enable smooth insertion when the condition becomes `true`.
        component ?? Card(parts: [nil])
    }

    public static func buildBlock<V: View>(_ v: V) -> Component {
        toCard(v)
    }

    public static func buildBlock<V0: View, V1: View>(_ v0: V0, _ v1: V1) -> Component {
        Card(reducing: [toCard(v0), toCard(v1)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View>(_ v0: V0, _ v1: V1, _ v2: V2) -> Component {
        Card(reducing: [toCard(v0), toCard(v1), toCard(v2)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3) -> Component {
        Card(reducing: [toCard(v0), toCard(v1), toCard(v2), toCard(v3)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4) -> Component {
        Card(reducing: [toCard(v0), toCard(v1), toCard(v2), toCard(v3), toCard(v4)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5) -> Component {
        Card(reducing: [toCard(v0), toCard(v1), toCard(v2), toCard(v3), toCard(v4), toCard(v5)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6) -> Component {
        Card(reducing: [toCard(v0), toCard(v1), toCard(v2), toCard(v3), toCard(v4), toCard(v5), toCard(v6)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7) -> Component {
        Card(reducing: [toCard(v0), toCard(v1), toCard(v2), toCard(v3), toCard(v4), toCard(v5), toCard(v6), toCard(v7)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8) -> Component {
        Card(reducing: [toCard(v0), toCard(v1), toCard(v2), toCard(v3), toCard(v4), toCard(v5), toCard(v6), toCard(v7), toCard(v8)])
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9) -> Component {
        Card(reducing: [toCard(v0), toCard(v1), toCard(v2), toCard(v3), toCard(v4), toCard(v5), toCard(v6), toCard(v7), toCard(v8), toCard(v9)])
    }

    // TODO: Simplify using `buildExpression` when Swift 5.2 is available.
    private static func toCard<V: View>(_ v: V) -> Card {
        if let card = v as? Card {
            return card
        } else if let splat = v as? Splat {
            return Card(components: [.dynamic(splat.identifiedViews)])
        } else {
            return Card(components: [.static(AnyView(v))])
        }
    }
}
