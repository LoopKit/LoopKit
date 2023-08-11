//
//  FavoriteFoodListRow.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 8/9/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit

public struct FavoriteFoodListRow: View {
    @Environment(\.editMode) var editMode
    
    private let cornerRadius: CGFloat = 10
    
    let food: StoredFavoriteFood
    @Binding var foodToConfirmDeleteId: String?
    
    let onTap: (StoredFavoriteFood) -> ()
    let onDelete: (StoredFavoriteFood) -> ()
    
    let carbFormatter: QuantityFormatter
    let absorptionTimeFormatter: DateComponentsFormatter
    let preferredCarbUnit: HKUnit

    public init(food: StoredFavoriteFood, foodToConfirmDeleteId: Binding<String?>, onFoodTap: @escaping (StoredFavoriteFood) -> Void, onFoodDelete: @escaping (StoredFavoriteFood) -> Void, carbFormatter: QuantityFormatter, absorptionTimeFormatter: DateComponentsFormatter, preferredCarbUnit: HKUnit = .gram()) {
        self.food = food
        self._foodToConfirmDeleteId = foodToConfirmDeleteId
        self.onTap = onFoodTap
        self.onDelete = onFoodDelete
        self.carbFormatter = carbFormatter
        self.absorptionTimeFormatter = absorptionTimeFormatter
        self.preferredCarbUnit = preferredCarbUnit
    }
    
    public var body: some View {
        let isEditing = editMode?.wrappedValue == .active
        let isConfirmingDelete = foodToConfirmDeleteId == food.id
        
        HStack(spacing: 0) {
            if isEditing {
                deleteButton
                    .onTapGesture {
                        if isConfirmingDelete {
                            onDelete(food)
                        }
                        else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                foodToConfirmDeleteId = food.id
                            }
                        }
                    }
            }
                        
            HStack {
                foodCardContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if isEditing {
                    editBars
                }
                else {
                    disclosure
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap(food)
            }
        }
    }
}

extension FavoriteFoodListRow {
    private var foodCardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(food.title)
            
            Text("\(food.carbsString(formatter: carbFormatter)) carbs, \(food.absorptionTimeString(formatter: absorptionTimeFormatter)) absorption")
                .font(.footnote)
        }
        .foregroundColor(.primary)
    }
    
    private var deleteButton: some View {
        let isEditing = editMode?.wrappedValue == .active
        let isConfirmingDelete = foodToConfirmDeleteId == food.id
        
        return ZStack {
            Color.red
                .clipShape(RoundedRectangle(cornerRadius: isConfirmingDelete ? 0 : 12.5))
                .frame(width: isConfirmingDelete ? nil : 25, height: isConfirmingDelete ? nil : 25)
            
            if isConfirmingDelete {
                Text("Delete")
                    .foregroundColor(.white)
            }
            else {
                Image(systemName: "minus")
                    .foregroundColor(.white)
            }
        }
        .frame(width: isEditing ? isConfirmingDelete ? 72 : 45 : 0, alignment: .trailing)
        .contentShape(Rectangle())
    }
    
    private var disclosure: some View {
        Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
            .foregroundColor(Color(UIColor.tertiaryLabel))
    }
    
    private var editBars: some View {
        Image(systemName: "line.3.horizontal")
            .foregroundColor(Color(UIColor.tertiaryLabel))
            .font(.title2)
    }
}
