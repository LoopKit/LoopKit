//
//  CheckmarkListItem.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct CheckmarkListItem<LeadingView: View>: View {
    
    var title: Text
    var titleFont: Font
    var description: Text
    @Binding var isSelected: Bool
    let isEnabled: Bool
    let leadingView: LeadingView?

    public init(
        title: Text,
        titleFont: Font = .headline,
        description: Text,
        isSelected: Binding<Bool>,
        isEnabled: Bool = true,
        @ViewBuilder leadingView: () -> LeadingView
    ) {
        self.title = title
        self.titleFont = titleFont
        self.description = description
        self._isSelected = isSelected
        self.isEnabled = isEnabled
        self.leadingView = leadingView()
    }
    
    public init(
        title: Text,
        titleFont: Font = .headline,
        description: Text,
        isSelected: Binding<Bool>,
        isEnabled: Bool = true
    ) where LeadingView == EmptyView {
        self.title = title
        self.titleFont = titleFont
        self.description = description
        self._isSelected = isSelected
        self.isEnabled = isEnabled
        self.leadingView = nil
    }

    @ViewBuilder
    public var body: some View {
        if isEnabled {
            Button(action: { self.isSelected = true }) {
                content
            }
            // Opt out of iOS 26 Liquid Glass's default button styling, which otherwise
            // wraps each row's custom label in a tinted Capsule background (ballooning into
            // ovals on the tall multi-line rows) and accent-tints all the text. .plain keeps
            // the row a borderless tappable item; the checkmark stays accent-colored via its
            // own foregroundColor.
            .buttonStyle(.plain)
        } else {
            content
        }
    }
    
    private var content: some View {
        HStack(spacing: 0) {
            if let leadingView = leadingView {
                leadingView
            }
            
            VStack(alignment: .leading, spacing: 4) {
                title
                    .font(titleFont)
                description
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 12)

            selectionIndicator
                .accessibility(label: Text(isSelected ? "Selected" : "Unselected"))
        }
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isEnabled {
            filledCheckmark
                .frame(width: 26, height: 26)
        } else {
            plainCheckmark
                .frame(width: 22, height: 22)
        }
    }
    
    @ViewBuilder
    private var filledCheckmark: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .background(Circle().stroke()) // Ensure size aligns with open circle
                .foregroundColor(.accentColor)
        } else {
            Circle()
                .stroke(lineWidth: 2)
                .foregroundColor(Color(.systemGray))
        }
    }
    
    @ViewBuilder
    private var plainCheckmark: some View {
        if isSelected {
            Image(systemName: "checkmark")
                .resizable()
                .foregroundColor(.accentColor)
        }
    }

}

public struct DurationBasedCheckmarkListItem: View {
   
    var title: Text
    var titleFont: Font
    var description: Text
    @Binding var isSelected: Bool
    let isEnabled: Bool
    @Binding var duration: TimeInterval
    var validDurationRange: ClosedRange<TimeInterval>

    public init(title: Text, titleFont: Font = .headline, description: Text, isSelected: Binding<Bool>, isEnabled: Bool = true,
                duration: Binding<TimeInterval>, validDurationRange: ClosedRange<TimeInterval>) {
        self.title = title
        self.titleFont = titleFont
        self.description = description
        self._isSelected = isSelected
        self.isEnabled = isEnabled
        self._duration = duration
        self.validDurationRange = validDurationRange
    }

    public var body: some View {
        VStack(spacing: 0) {
            CheckmarkListItem(title: title, titleFont: titleFont, description: description, isSelected: $isSelected, isEnabled: isEnabled)

            if isSelected {
                DurationPicker(duration: $duration, validDurationRange: validDurationRange)
                    .frame(height: 216)
                    .transition(.fadeInFromTop)
            }
        }
    }
}
