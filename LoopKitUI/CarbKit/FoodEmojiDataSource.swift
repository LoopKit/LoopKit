//
//  FoodEmojiDataSource.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

public func CarbAbsorptionInputController() -> EmojiInputController {
    return EmojiInputController.instance(withEmojis: FoodEmojiDataSource())
}


private class FoodEmojiDataSource: EmojiDataSource {
    private static let fast: [String] = {
        var fast = [
            "🍭", "🍬", "🍯",
            "🍇", "🍈", "🍉", "🍊", "🍋", "🍌", "🍍",
            "🍎", "🍏", "🍐", "🍑", "🍒", "🍓", "🥝",
            "🌽", "🍿", "🍘", "🍡", "🍦", "🍧", "🎂", "🥠",
            "☕️",
        ]

        return fast
    }()

    private static let medium: [String] = {
        var medium = [
            "🌮", "🍟", "🍳", "🍲", "🍱", "🍛",
            "🍜", "🍠", "🍤", "🍥",
            "🥪", "🥫", "🥟", "🥡", "🍢", "🍣",
            "🍅", "🥔", "🥕", "🌶", "🥒", "🥗", "🍄", "🥦",
            "🍆", "🥥", "🍞", "🥐", "🥖", "🥨", "🥞", "🍙", "🍚",
            "🍼", "🥛", "🍮", "🥧",
            "🍨", "🍩", "🍪", "🍰", "🍫",
       ]

        return medium
    }()

    private static let slow: [String] = {
        var slow = [
            "🍕", "🥑", "🥜", "🌰", "🧀", "🍖", "🍗", "🥓",
            "🍔", "🌭", "🌯", "🍝", "🥩"
        ]

        return slow
    }()

    private static let other: [String] = {
        var other = [
            "🍶", "🍾", "🍷", "🍸", "🍺", "🍻", "🥂", "🥃",
            "🍹", "🥣", "🥤", "🥢", "🍵",
            "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣",
            "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟"
        ]

        return other
    }()

    let sections: [EmojiSection]

    init() {
        sections = [
            EmojiSection(
                title: LocalizedString("Fast", comment: "Section title for fast absorbing food"),
                items: type(of: self).fast,
                indexSymbol: " 🍭 "
            ),
            EmojiSection(
                title: LocalizedString("Medium", comment: "Section title for medium absorbing food"),
                items: type(of: self).medium,
                indexSymbol: "🌮"
            ),
            EmojiSection(
                title: LocalizedString("Slow", comment: "Section title for slow absorbing food"),
                items: type(of: self).slow,
                indexSymbol: "🍕"
            ),
            EmojiSection(
                title: LocalizedString("Other", comment: "Section title for no-carb food"),
                items: type(of: self).other,
                indexSymbol: "⋯ "
            )
        ]
    }
}
