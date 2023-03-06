//
//  FoodEmojiDataSource.swift
//  LoopKit
//
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

public func CarbAbsorptionInputController() -> EmojiInputController {
    return EmojiInputController.instance(withEmojis: FoodEmojiDataSource())
}


private class FoodEmojiDataSource: EmojiDataSource {
    private static let fast: [String] = {
        var fast = [
            "🍭", // lollipop
            "🧃", // juice box
            "🍫", // chocolate
            "🥤", // cup with straw (soda)
            "🍬", // candy
            "🍯", // honey
            "🍦", // soft ice cream
            "🍧", // shaved ice
            "🍨", // ice cream
            "🎂", // birthday cake
            "🍰", // shotcake
            "🍩", // doughnut
            "🍪", // cookie
            "🍇", // grapes
            "🍈", // melon
            "🍉", // watermelon
            "🍊", // tangerine
            "🍋", // lemon
            "🍌", // bananna
            "🫐", // blueberries
            "🍍", // pineapple
            "🍎", // red apple
            "🍏", // green apple
            "🍐", // pear
            "🍑", // peach
            "🍒", // cherries
            "🍓", // strawberries
            "🥝", // kiwi fruit
            "🌽", // corn
            "🍿", // popcorn
            "🍘", // rice cake
            "🥠", // fortune cookie
            "🍡", // dango
            "☕️", // coffee
            "🫖", // tea
        ]

        return fast
    }()

    private static let medium: [String] = {
        var medium = [
            "🌮", // taco
            "🍟", // french fries
            "🍳", // cooking (eggs)
            "🍲", // pot of food
            "🍱", // bento box
            "🍛", // curry and rice
            "🍜", // steaming bowl
            "🍠", // roasted sweet potato
            "🍤", // fried shrimp
            "🍥", // fish cake
            "🍙", // rice ball
            "🍚", // cooked rice
            "🥪", // sandwich
            "🥫", // canned food
            "🥟", // dumpling
            "🥡", // takeout box
            "🍢", // oden
            "🍣", // sushi
            "🍅", // tomato
            "🥔", // potato
            "🥕", // carrot
            "🌶", // hot pepper
            "🥒", // cucumber
            "🥗", // green salad
            "🍄", // mushroom
            "🥦", // broccoli
            "🥬", // leafy green
            "🍆", // eggplant
            "🥥", // coconut
            "🍞", // bread
            "🥐", // croissant
            "🥖", // baguette bread
            "🥨", // pretzel
            "🥞", // pancakes
            "🍼", // baby bottle
            "🥛", // glass of milk
            "🍮", // custard
            "🥧", // pie
       ]

        return medium
    }()

    private static let slow: [String] = {
        var slow = [
            "🍕", // pizza
            "🥑", // avocado
            "🥜", // peanuts
            "🌰", // chestnut
            "🧀", // cheese wedge
            "🍖", // meat on bone
            "🍗", // poultry leg
            "🥓", // bacon
            "🍔", // hamburger
            "🌭", // hot dog
            "🌯", // burrito
            "🍝", // spaghetti
            "🥩", // cut of meat
            "🍳", // cooking (eggs)
        ]

        return slow
    }()

    private static let other: [String] = {
        var other = [
            "🍶", // sake
            "🍾", // bottle with popping cork (champagne)
            "🍷", // wine
            "🍸", // cocktail
            "🍺", // beer
            "🍻", // clinking beer mugs
            "🥂", // clinking glasses
            "🥃", // tumbler glass
            "🍹", // tropical drink
            "🥣", // bowl with spoon
            "🥤", // cup with straw
            "🥢", // chopsticks
            "🍵", // teacup without handle
            "🍴", // fork and knife
            "🍽", // fork and knife with plate
            "🥄", // spoon
            "😋"  // face savoring food
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
