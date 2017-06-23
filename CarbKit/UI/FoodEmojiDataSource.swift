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
    private static let fast   = ["🍭", "🍇", "🍈", "🍉", "🍊", "🍋", "🍌", "🍍",
                                 "🍎", "🍏", "🍐", "🍑", "🍒", "🍓", "🥝",
                                 "🍅", "🥔", "🥕", "🌽", "🌶", "🥒", "🥗", "🍄",
                                 "🍞", "🥐", "🥖", "🥞", "🍿", "🍘", "🍙",
                                 "🍚", "🍢", "🍣", "🍡", "🍦", "🍧", "🍨",
                                 "🍩", "🍪", "🎂", "🍰", "🍫", "🍬", "🍮",
                                 "🍯", "🍼", "🥛", "☕️", "🍵"]
    private static let medium = ["🌮", "🍆", "🍟", "🍳", "🍲", "🍱", "🍛",
                                 "🍜", "🍠", "🍤", "🍥", "🍹"]
    private static let slow   = ["🍕", "🥑", "🥜", "🌰", "🧀", "🍖", "🍗", "🥓",
                                 "🍔", "🌭", "🌯", "🍝"]
    private static let other  = ["🍶", "🍾", "🍷", "🍸", "🍺", "🍻", "🥂", "🥃",
                                 "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣",
                                 "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟"]
    let sections: [FoodEmojiSection]

    init() {
        sections = [
            FoodEmojiSection(
                items: type(of: self).fast,
                title: NSLocalizedString("Fast", comment: "Section title for fast absorbing food")
            ),
            FoodEmojiSection(
                items: type(of: self).medium,
                title: NSLocalizedString("Medium", comment: "Section title for medium absorbing food")
            ),
            FoodEmojiSection(
                items: type(of: self).slow,
                title: NSLocalizedString("Slow", comment: "Section title for slow absorbing food")
            ),
            FoodEmojiSection(
                items: type(of: self).other,
                title: NSLocalizedString("Other", comment: "Section title for no-carb food")
            )
        ]
    }

    func maxAbsorptionTimeIndexForText(_ text: String) -> Int? {
        for (index, section) in sections.dropLast().enumerated().reversed() {
            for character in text.characters {
                if section.items.contains(String(character)) {
                    return index
                }
            }
        }

        return nil
    }
}
