//
//  OverrideEmojiDataSource.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 1/7/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

func OverrideSymbolInputController() -> EmojiInputController {
    return EmojiInputController.instance(withEmojis: OverrideEmojiDataSource())
}


private final class OverrideEmojiDataSource: EmojiDataSource {

    private static let activity = [
        "🚶‍♀️", "🚶‍♂️", "🏃‍♀️", "🏃‍♂️", "💃", "🕺",
        "⚽️", "🏀", "🏈", "⚾️", "🥎", "🎾",
        "🏐", "🏉", "🥏", "🎳", "🏓", "🏸",
        "🏒", "🏑", "🥍", "🏏", "⛳️", "🏹",
        "🥊", "🥋", "🛹", "⛸", "🥌", "🛷",
        "⛷", "🏂", "🏋️‍♀️", "🏋️‍♂️", "🤼‍♀️", "🤼‍♂️",
        "🤸‍♀️", "🤸‍♂️", "⛹️‍♀️", "⛹️‍♂️", "🤺", "🤾‍♀️",
        "🤾‍♂️", "🏌️‍♀️", "🏌️‍♂️", "🏇", "🧘‍♀️", "🧘‍♂️",
        "🏄‍♀️", "🏄‍♂️", "🏊‍♀️", "🏊‍♂️", "🤽‍♀️", "🤽‍♂️",
        "🚣‍♀️", "🚣‍♂️", "🧗‍♀️", "🧗‍♂️", "🚵‍♀️", "🚵‍♂️",
        "🚴‍♀️", "🚴‍♂️", "🎪", "🤹‍♀️", "🤹‍♂️", "🎭",
        "🎤", "🎯", "🎳", "🥾", "⛺️", "🐕",
    ]

    private static let condition = [
        "🤒", "🤢", "🤮", "😷", "🤕", "😰",
        "🥵", "🥶", "😘", "🧟‍♀️", "🧟‍♂️", "📅",
        "💊", "🍸", "🎉","⛰", "🏔", "🚗",
        "✈️", "🎢",
    ]

    private static let other = [
        "➕", "➖", "⬆️", "⬇️",
        "❗️", "❓", "‼️", "⁉️", "❌", "⚠️",
        "0️⃣", "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣",
        "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟",
    ]

    let sections: [EmojiSection]

    init() {
        sections = [
            EmojiSection(
                title: NSLocalizedString("Activity", comment: "The title for the override emoji activity section"),
                items: type(of: self).activity,
                indexSymbol: " 🏃‍♀️ "
            ),
            EmojiSection(
                title: NSLocalizedString("Condition", comment: "The title for the override emoji condition section"),
                items: type(of: self).condition,
                indexSymbol: "🤒"
            ),
            EmojiSection(
                title: NSLocalizedString("Other", comment: "The title for override emoji miscellaneous section"),
                items: type(of: self).other,
                indexSymbol: "⋯ "
            )
        ]
    }
}
