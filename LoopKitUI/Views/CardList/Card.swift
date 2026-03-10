//
//  Card.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


/// A platter displaying a number of components over a rounded background tile.
///
/// In a `CardStackBuilder`, a single-component `Card` is implicitly created from any expression conforming to `View`.
/// A multi-component `Card` can be constructed using one of `Card`'s initializers.
///
/// A multi-component card may consist of purely static components:
/// ```
/// Card {
///     Text("Top")
///     Text("Middle")
///     Text("Bottom")
/// }
/// ```
///
/// Cards of a dynamic number of components can be constructed from identifiable data:
/// ```
/// Card(of: 1...5, id: \.self) { value in
///     Text("\(value)")
/// }
/// ```
///
/// Finally, dynamic components can be unrolled to intermix with static components via `Splat`:
/// ```
/// Card {
///     Text("Above dynamic data")
///     Splat(1...5, id: \.self) { value in
///         Text("Dynamic data \(value)")
///     }
///     Text("Below dynamic data")
/// }
/// ```
public struct Card: View {
    var hero: AnyView?
    var parts: [AnyView?]
    var backgroundColor: Color
    
    init<Hero: View>(hero: Hero? = nil, parts: [AnyView?], backgroundColor: Color = Color(.secondarySystemGroupedBackground)) {
        if let hero, !(hero is EmptyView) {
            self.hero = AnyView(hero)
        }
        
        self.parts = parts
        self.backgroundColor = backgroundColor
    }
    
    init(hero: EmptyView? = nil, parts: [AnyView?], backgroundColor: Color = Color(.secondarySystemGroupedBackground)) {
        self.hero = nil
        self.parts = parts
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        VStack {
            if let hero {
                hero
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            }
            
            VStack {
                ForEach(parts.indices, id: \.self) { index in
                    Group {
                        if self.parts[index] != nil {
                            VStack {
                                self.parts[index]!
                                    .padding(.top, index == 0 || hero != nil ? 0 : 4)
                                
                                if index != self.parts.indices.last! {
                                    CardSectionDivider()
                                }
                            }
                            .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(color: backgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal)
    }
}

extension Card {
    init(_ other: Self, backgroundColor: Color? = nil) {
        self.hero = other.hero
        self.parts = other.parts
        self.backgroundColor = backgroundColor ?? other.backgroundColor
    }

    func backgroundColor(_ color: Color?) -> Self { Self(self, backgroundColor: color) }
}

extension Card {
    public enum Component {
        case `static`(AnyView)
        case dynamic([(view: AnyView, id: AnyHashable)])
    }

    public init<Hero: View>(hero: Hero? = nil, @CardBuilder card: () -> Card) {
        let card = card()
        
        if let hero, !(hero is EmptyView) {
            self.hero = AnyView(hero)
        }

        self.parts = card.parts
        self.backgroundColor = card.backgroundColor
    }
    
    public init(hero: EmptyView? = nil, @CardBuilder card: () -> Card) {
        let card = card()
        
        self.hero = nil
        self.parts = card.parts
        self.backgroundColor = card.backgroundColor
    }

    public init<Data: RandomAccessCollection, ID: Hashable, Content: View>(
        of data: Data,
        id: KeyPath<Data.Element, ID>,
        rowContent: (Data.Element) -> Content
    ) {
        self.init(components: [.dynamic(Splat(data, id: id, rowContent: rowContent).identifiedViews)])
    }

    public init<Data: RandomAccessCollection, Content: View>(
        of data: Data,
        @ViewBuilder rowContent:  (Data.Element) -> Content
    ) where Data.Element: Identifiable {
        self.init(of: data, id: \.id, rowContent: rowContent)
    }

    init<Hero: View>(hero: Hero? = nil, reducing cards: [Card], backgroundColor: Color = Color(.secondarySystemGroupedBackground)) {
        if let hero, !(hero is EmptyView) {
            self.hero = AnyView(hero)
        }
        self.parts = cards.flatMap { $0.parts }
        self.backgroundColor = backgroundColor
    }
    
    init(hero: EmptyView? = nil, reducing cards: [Card], backgroundColor: Color = Color(.secondarySystemGroupedBackground)) {
        self.hero = nil
        self.parts = cards.flatMap { $0.parts }
        self.backgroundColor = backgroundColor
    }
    
    /// `nil` values denote placeholder positions where a view may become visible upon state change.
    init<Hero: View>(hero: Hero? = nil, components: [Component?], backgroundColor: Color = Color(.secondarySystemGroupedBackground)) {
        if let hero, !(hero is EmptyView) {
            self.hero = AnyView(hero)
        }
        
        self.parts = components.map { component in
            switch component {
            case .static(let view):
                return view
            case .dynamic(let identifiedViews):
                return AnyView(
                    ForEach(identifiedViews, id: \.id) { view, id in
                        VStack {
                            view
                            if id != identifiedViews.last?.id {
                                CardSectionDivider()
                            }
                        }
                    }
                )
            case nil:
                return nil
            }
        }
        self.backgroundColor = backgroundColor
    }
    
    init(hero: EmptyView? = nil, components: [Component?], backgroundColor: Color = Color(.secondarySystemGroupedBackground)) {
        self.hero = nil
        
        self.parts = components.map { component in
            switch component {
            case .static(let view):
                return view
            case .dynamic(let identifiedViews):
                return AnyView(
                    ForEach(identifiedViews, id: \.id) { view, id in
                        VStack {
                            view
                            if id != identifiedViews.last?.id {
                                CardSectionDivider()
                            }
                        }
                    }
                )
            case nil:
                return nil
            }
        }
        self.backgroundColor = backgroundColor
    }
}

public struct CardBackground: View {
    var color: Color
    
    public init(color: Color = Color(.secondarySystemGroupedBackground)) {
        self.color = color
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .foregroundColor(color)
    }
}

public struct CardSectionDivider: View {
    public init() {}
    
    public var body: some View {
        Divider()
            .padding(.trailing, -16)
    }
}
