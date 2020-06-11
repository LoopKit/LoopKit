//
//  ScheduleItemView.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


struct ScheduleItemView<ValueContent: View, ExpandedContent: View>: View {
    var time: TimeInterval
    @Binding var isEditing: Bool
    var valueContent: ValueContent
    var expandedContent: ExpandedContent

    private let fixedMidnight = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))

    init(
        time: TimeInterval,
        isEditing: Binding<Bool>,
        @ViewBuilder valueContent: () -> ValueContent,
        @ViewBuilder expandedContent: () -> ExpandedContent
    ) {
        self.time = time
        self._isEditing = isEditing
        self.valueContent = valueContent()
        self.expandedContent = expandedContent()
    }

    var body: some View {
        ExpandableSetting(
            isEditing: $isEditing,
            leadingValueContent: { timeText },
            trailingValueContent: { valueContent },
            expandedContent: { self.expandedContent }
        )
    }

    private var timeText: Text {
        let dayAtTime = fixedMidnight.addingTimeInterval(time)
        return Text(DateFormatter.localizedString(from: dayAtTime, dateStyle: .none, timeStyle: .short))
            .foregroundColor(isEditing ? .accentColor : Color(.label))
    }
}

extension AnyTransition {
    static let fadeInFromTop = move(edge: .top).combined(with: .opacity)
        .delayingInsertion(by: 0.1)
        .speedingUpRemoval(by: 1.8)

    func delayingInsertion(by delay: TimeInterval) -> AnyTransition {
        .asymmetric(insertion: animation(Animation.default.delay(delay)), removal: self)
    }

    func speedingUpRemoval(by factor: Double) -> AnyTransition {
        .asymmetric(insertion: self, removal: animation(Animation.default.speed(factor)))
    }
}
