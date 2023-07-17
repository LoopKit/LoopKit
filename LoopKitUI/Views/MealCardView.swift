//
//  MealCardView.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/12/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct MealCardView: View {
    @Environment(\.editMode) var editMode
    
    private let cornerRadius: CGFloat = 10
    
    let meal: Meal
    @Binding var mealToConfirmDeleteId: String?
    
    let onTap: (Meal) -> ()
    let onDelete: (Meal) -> ()

    public init(meal: Meal, mealToConfirmDeleteId: Binding<String?>, onMealTap: @escaping (Meal) -> Void, onMealDelete: @escaping (Meal) -> Void) {
        self.meal = meal
        self._mealToConfirmDeleteId = mealToConfirmDeleteId
        self.onTap = onMealTap
        self.onDelete = onMealDelete
    }
    
    public var body: some View {
        let isEditing = editMode?.wrappedValue == .active
        let isConfirmingDelete = mealToConfirmDeleteId == meal.id
        
        HStack(spacing: 0) {
            if isEditing {
                deleteButton
                .onTapGesture {
                    if isConfirmingDelete {
                        onDelete(meal)
                    }
                    else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            mealToConfirmDeleteId = meal.id
                        }
                    }
                }
            }
            
            Button(action: { onTap(meal) }) {
                HStack {
                    mealCardContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if isEditing {
                        editBars
                    }
                    else {
                        disclosure
                    }
                }
                .padding(10)
                .contentShape(Rectangle())
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(isConfirmingDelete ? Color.red : Color(UIColor.systemGray4))
        )
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension MealCardView {
    private var mealCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meal.name)
                .foregroundColor(.primary)
                .fontWeight(.semibold)
            
            Text(meal.foodType)
                .fontWeight(.semibold)
            
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Carbs")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text(meal.carbsString)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Circle()
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                    .frame(width: 4)
                    .offset(y: 8) // so the dot goes between the bottom texts of the two VStacks
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Absorption Time")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text(meal.absorptionTimeString)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    private var deleteButton: some View {
        let isEditing = editMode?.wrappedValue == .active
        let isConfirmingDelete = mealToConfirmDeleteId == meal.id
        let deleteButtonWidth: CGFloat = isEditing ? isConfirmingDelete ? 72 : 32 : 0
        
        return ZStack {
            Color.red
            
            if isConfirmingDelete {
                Text("Delete")
                    .foregroundColor(.white)
            }
            else {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            }
        }
        .frame(width: deleteButtonWidth)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
    }
    
    private var disclosure: some View {
        Image(systemName: "chevron.forward")
            .font(.headline.bold())
            .foregroundColor(Color(UIColor.tertiaryLabel))
    }
    
    private var editBars: some View {
        Image(systemName: "line.3.horizontal")
            .foregroundColor(Color(UIColor.tertiaryLabel))
            .font(.title2)
    }
}
