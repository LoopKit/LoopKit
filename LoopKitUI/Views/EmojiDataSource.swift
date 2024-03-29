//
//  EmojiDataSource.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 1/7/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

struct EmojiSection {
    let title: String
    let items: [String]
    let indexSymbol: String
}

protocol EmojiDataSource {
    var sections: [EmojiSection] { get }
}

public enum EmojiDataSourceType {
    case food
    case override
    
    func dataSource() -> EmojiDataSource {
        switch self {
        case .food:
            return FoodEmojiDataSource()
        case .override:
            return OverrideEmojiDataSource()
        }
    }
}
