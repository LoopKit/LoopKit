//
//  BulletedListView.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-07-08.
//  Copyright © 2021 Tidepool Project. All rights reserved.
//

import SwiftUI

@resultBuilder
public struct BulletedListBuilder {
    public static func buildBlock(_ components: Text...) -> [Text] {
        components
    }
    
    public static func buildBlock(_ components: String...) -> [Text] {
        components.map({ Text($0) })
    }
}

public struct BulletedListView: View {
    private let bulletedList: [Text]
    private let bulletColor: Color
    private let bulletOpacity: Double
    
    public init(bulletColor: Color = .accentColor, bulletOpacity: Double = 0.5, @BulletedListBuilder _ bulletedList: () -> [Text]) {
        self.bulletColor = bulletColor
        self.bulletOpacity = bulletOpacity
        self.bulletedList = bulletedList()
    }
    
    public init(bulletColor: Color = .accentColor, bulletOpacity: Double = 0.5, _ bulletedList: [String]) {
        self.bulletColor = bulletColor
        self.bulletOpacity = bulletOpacity
        self.bulletedList = bulletedList.map({ Text($0) })
    }

    public var body: some View {
        VStack(alignment: .leading) {
            ForEach(Array(bulletedList.enumerated()), id: \.offset) { bullet in
                HStack(spacing: 16) {
                    Bullet(color: bulletColor, opacity: bulletOpacity)
                    bullet.element
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

public struct Bullet: View {
    @ScaledMetric var size: CGFloat = 8
    let color: Color
    let opacity: Double
    
    public init(color: Color = .accentColor, opacity: Double = 0.5) {
        self.color = color
        self.opacity = opacity
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
