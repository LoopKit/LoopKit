//
//  BulletedListView.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-07-08.
//  Copyright © 2021 Tidepool Project. All rights reserved.
//

import SwiftUI

@resultBuilder
public enum BulletedListBuilder {
    public static func buildBlock(_ components: BulletRow...) -> [BulletRow] { components }
    public static func buildOptional(_ component: [BulletRow]?) -> [BulletRow] { component ?? [] }
    public static func buildEither(first component: [BulletRow]) -> [BulletRow] { component }
    public static func buildEither(second component: [BulletRow]) -> [BulletRow] { component }
    public static func buildArray(_ components: [[BulletRow]]) -> [BulletRow] { components.flatMap { $0 } }
    public static func buildExpression(_ expression: String) -> BulletRow { BulletRow { Text(expression) } }
    public static func buildExpression(_ expression: Text) -> BulletRow { BulletRow { expression }}
    public static func buildExpression<V: View>(_ expression: V) -> BulletRow { BulletRow { expression } }
}

public struct BulletedListView: View {
    private let bulletedList: [BulletRow]
    private let bulletColor: Color
    private let bulletOpacity: Double
    private let bulletSize: Double
    private let bulletAlignment: VerticalAlignment

    public init(
        bulletColor: Color = .accentColor,
        bulletOpacity: Double = 0.5,
        bulletSize: Double = 8,
        bulletAlignment: VerticalAlignment = .center,
        @BulletedListBuilder _ bulletedList: () -> [BulletRow]
    ) {
        self.bulletColor = bulletColor
        self.bulletOpacity = bulletOpacity
        self.bulletSize = bulletSize
        self.bulletAlignment = bulletAlignment
        self.bulletedList = bulletedList()
    }

    public init(
        bulletColor: Color = .accentColor,
        bulletOpacity: Double = 0.5,
        bulletSize: Double = 8,
        bulletAlignment: VerticalAlignment = .center,
        _ bulletedList: [String]
    ) {
        self.bulletColor = bulletColor
        self.bulletOpacity = bulletOpacity
        self.bulletSize = bulletSize
        self.bulletAlignment = bulletAlignment
        self.bulletedList = bulletedList.map { string in BulletRow { Text(string) } }
    }

    public var body: some View {
        VStack(alignment: .leading) {
            ForEach(Array(bulletedList.enumerated()), id: \.offset) { bullet in
                HStack(alignment: bulletAlignment, spacing: 16) {
                    Bullet(color: bulletColor, opacity: bulletOpacity, size: bulletSize)
                    bullet.element
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

public struct BulletRow: View {
    private let content: AnyView

    public init<V: View>(@ViewBuilder body: () -> V) {
        self.content = AnyView(body())
    }

    public var body: some View {
        content
    }
}

public struct Bullet: View {
    let size: CGFloat
    let color: Color
    let opacity: Double

    public init(color: Color = .accentColor, opacity: Double = 0.5, size: Double = 8) {
        self.color = color
        self.opacity = opacity
        self.size = UIFontMetrics.default.scaledValue(for: size)
    }

    public var body: some View {
        Circle()
            .frame(width: size, height: size)
            .opacity(opacity)
            .foregroundColor(color)
    }
}

struct BulletedListView_Previews: PreviewProvider {
    static var previews: some View {
        BulletedListView {
            "This is a step."
            "This is another step that is a bit more tricky and needs more description to support the user, albeit it could be more concise."
            "This the last step in the list, and with it the list is complete."
        }
    }
}
