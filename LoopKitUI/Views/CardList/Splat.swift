//
//  Splat.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


/// A structure representing multiple components of one `Card`.
///
/// Use `Splat` to intermix static and dynamic card components:
/// ```
/// Card {
///     Text("Above dynamic data")
///     Splat(1...5, id: \.self) { value in
///         Text("Dynamic data \(value)")
///     }
///     Text("Below dynamic data")
/// }
/// ```
public struct Splat: View {
    var identifiedViews: [(view: AnyView, id: AnyHashable)]

    public init<Data: RandomAccessCollection, ID: Hashable, Content: View>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder rowContent:  (Data.Element) -> Content
    ) {
        identifiedViews = data.map { datum in
            (view: AnyView(rowContent(datum)), id: datum[keyPath: id])
        }
    }

    public init<Data: RandomAccessCollection, Content: View>(
        _ data: Data,
        @ViewBuilder rowContent:  (Data.Element) -> Content
    ) where Data.Element: Identifiable {
        self.init(data, id: \.id, rowContent: rowContent)
    }

    public var body: some View {
        Card(components: [.dynamic(identifiedViews)])
    }
}
