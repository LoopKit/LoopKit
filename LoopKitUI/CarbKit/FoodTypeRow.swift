//
//  FoodTypeRow.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct FoodTypeRow: View {
    @Binding private var foodType: String
    @Binding private var absorptionTime: TimeInterval
    @Binding private var selectedDefaultAbsorptionTimeEmoji: String
    @Binding private var usesCustomFoodType: Bool
    @Binding private var absorptionTimeWasEdited: Bool
    @Binding private var isFocused: Bool
    
    private var defaultAbsorptionTimes: CarbStore.DefaultAbsorptionTimes
    private var orderedAbsorptionTimes: [TimeInterval] {
        [defaultAbsorptionTimes.fast, defaultAbsorptionTimes.medium, defaultAbsorptionTimes.slow]
    }
    
    private let emojiShortcuts = FoodEmojiShortcut.all
    
    @State private var selectedEmojiIndex = 1
    
    /// Contains emoji shortcuts, an emoji keyboard, and modifies absorption time to match emoji
    public init(foodType: Binding<String>, absorptionTime: Binding<TimeInterval>, selectedDefaultAbsorptionTimeEmoji: Binding<String>, usesCustomFoodType: Binding<Bool>, absorptionTimeWasEdited: Binding<Bool>, isFocused: Binding<Bool>, defaultAbsorptionTimes: CarbStore.DefaultAbsorptionTimes) {
        self._foodType = foodType
        self._absorptionTime = absorptionTime
        self._selectedDefaultAbsorptionTimeEmoji = selectedDefaultAbsorptionTimeEmoji
        self._usesCustomFoodType = usesCustomFoodType
        self._absorptionTimeWasEdited = absorptionTimeWasEdited
        self._isFocused = isFocused
        
        self.defaultAbsorptionTimes = defaultAbsorptionTimes
    }
    
    public var body: some View {
        HStack {
            Text("Food Type")
                .foregroundColor(.primary)
            
            Spacer()
            
            if usesCustomFoodType {
                RowEmojiTextField(text: $foodType, isFocused: $isFocused, emojiType: .food, didSelectItemInSection: didSelectEmojiInSection)
                    .onTapGesture {
                        // so that row does not lose focus on cursor move
                        if !isFocused {
                            rowTapped()
                        }
                    }
            }
            else {
                HStack(spacing: 5) {
                    ForEach(emojiShortcuts.indices, id: \.self) { index in
                        let isSelected = index == selectedEmojiIndex
                        let option = emojiShortcuts[index]
                        Text(option.emoji)
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .background(isSelected ? Color.gray.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onTapGesture {
                                switch option {
                                case .other:
                                    rowTapped()
                                default:
                                    selectedDefaultAbsorptionTimeEmoji = option.emoji
                                    selectedEmojiIndex = index
                                    absorptionTime = orderedAbsorptionTimes[index]
                                }
                            }
                    }
                }
                .onAppear {
                    selectedDefaultAbsorptionTimeEmoji = emojiShortcuts[selectedEmojiIndex].emoji
                }
            }
        }
        .frame(height: 44)
        .padding(.vertical, -8)
        .onTapGesture {
            rowTapped()
        }
    }
    
    private func didSelectEmojiInSection(_ section: Int) {
        // only adjust if it wasn't already edited, food selected was not in other category
        guard !absorptionTimeWasEdited, section < orderedAbsorptionTimes.count else {
            return
        }
        
        absorptionTime = orderedAbsorptionTimes[section]
    }
    
    private func rowTapped() {
        withAnimation {
            if !isFocused {
                usesCustomFoodType = true
            }
            isFocused.toggle()
        }
    }
}

fileprivate enum FoodEmojiShortcut {
    case fast(emoji: String)
    case medium(emoji: String)
    case slow(emoji: String)
    case other
    
    var emoji: String {
        switch self {
        case .fast(emoji: let emoji):
            return emoji
        case .medium(emoji: let emoji):
            return emoji
        case .slow(emoji: let emoji):
            return emoji
        case .other:
            return "🍽️"
        }
    }
    
    static let all: [FoodEmojiShortcut] = [
        .fast(emoji: "🍭"),
        .medium(emoji: "🌮"),
        .slow(emoji: "🍕"),
        .other
    ]
}
