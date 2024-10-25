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
    
    public init(@BulletedListBuilder _ bulletedList: () -> [Text]) {
        self.bulletedList = bulletedList()
    }
    
    public init(_ bulletedList: [String]) {
        self.bulletedList = bulletedList.map({ Text($0) })
    }

    public var body: some View {
        VStack(alignment: .leading) {
            ForEach(Array(bulletedList.enumerated()), id: \.offset) { bullet in
                HStack(spacing: 16) {
                    Bullet()
                    bullet.element
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct Bullet: View {
    @ScaledMetric var size: CGFloat = 8

    var body: some View {
        Circle()
            .frame(width: size, height: size)
            .opacity(0.5)
            .foregroundColor(.accentColor)
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
