//
//  FoodEmojiDataSource.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//


struct FoodEmojiSection {
    let items: [String]
    let title: String
}


class FoodEmojiDataSource {
    private static let fast: [String] = {
        var fast = [
            "🍭", "🍇", "🍈", "🍉", "🍊", "🍋", "🍌", "🍍",
            "🍎", "🍏", "🍐", "🍑", "🍒", "🍓", "🥝",
            "🍅", "🥔", "🥕", "🌽", "🌶", "🥒", "🥗", "🍄",
            "🍞", "🥐", "🥖", "🥞", "🍿", "🍘", "🍙",
            "🍚", "🍢", "🍣", "🍡", "🍦", "🍧", "🍨",
            "🍩", "🍪", "🎂", "🍰", "🍫", "🍬", "🍮",
            "🍯", "🍼", "🥛", "☕️", "🍵",
            "🥥", "🥦", "🥨", "🥠", "🥧",
        ]

        return fast
    }()

    private static let medium: [String] = {
        var medium = [
            "🌮", "🍆", "🍟", "🍳", "🍲", "🍱", "🍛",
            "🍜", "🍠", "🍤", "🍥", "🍹",
            "🥪", "🥫", "🥟", "🥡",
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
            "🥣", "🥤", "🥢",
            "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣",
            "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟"
        ]

        return other
    }()

    let sections: [FoodEmojiSection]

    init() {
        sections = [
            FoodEmojiSection(
                items: type(of: self).fast,
                title: LocalizedString("Fast", comment: "Section title for fast absorbing food")
            ),
            FoodEmojiSection(
                items: type(of: self).medium,
                title: LocalizedString("Medium", comment: "Section title for medium absorbing food")
            ),
            FoodEmojiSection(
                items: type(of: self).slow,
                title: LocalizedString("Slow", comment: "Section title for slow absorbing food")
            ),
            FoodEmojiSection(
                items: type(of: self).other,
                title: LocalizedString("Other", comment: "Section title for no-carb food")
            )
        ]
    }

    func maxAbsorptionTimeIndexForText(_ text: String) -> Int? {
        for (index, section) in sections.dropLast().enumerated().reversed() {
            for character in text {
                if section.items.contains(String(character)) {
                    return index
                }
            }
        }

        return nil
    }
}
