//
//  Deletable.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


enum TableDeletionState: Equatable {
    case disabled
    case enabled
    case awaitingConfirmation(toDeleteItemAt: Int)

    var isAwaitingConfirmation: Bool {
        if case .awaitingConfirmation = self {
            return true
        } else {
            return false
        }
    }

    var indexAwaitingDeletionConfirmation: Int? {
        if case .awaitingConfirmation(toDeleteItemAt: let index) = self {
            return index
        } else {
            return nil
        }
    }
}


/// Mimics the behavior of UITableViewCell deletion.
///
/// As of Xcode 11.4, SwiftUI's List does not play nicely with resizing cells.
/// CardList solves this issue while retaining the appearance of an inset grouped table.
/// However, by avoiding List, we also lose built-in deletion functionality, requiring this implementation.
struct Deletable<Content: View>: View {
    @Binding var tableDeletionState: TableDeletionState
    var index: Int
    var isDeletable: Bool
    var delete: () -> Void
    var content: Content

    init(
        tableDeletionState: Binding<TableDeletionState>,
        index: Int,
        isDeletable: Bool,
        onDelete delete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self._tableDeletionState = tableDeletionState
        self.index = index
        self.isDeletable = isDeletable
        self.delete = delete
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 16) {
            if isDeletable &&
                tableDeletionState != .disabled &&
                tableDeletionState.indexAwaitingDeletionConfirmation != index
            {
                DeletionIndicator()
                    .transition(AnyTransition.move(edge: .leading).combined(with: .opacity))
                    .onTapGesture {
                        withAnimation {
                            self.tableDeletionState = .awaitingConfirmation(toDeleteItemAt: self.index)
                        }
                    }
            }

            HStack(spacing: 16) {
                content
                    .disabled(tableDeletionState != .disabled)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if self.tableDeletionState.isAwaitingConfirmation {
                            withAnimation {
                                self.tableDeletionState = .enabled
                            }
                        }
                    }

                if tableDeletionState.indexAwaitingDeletionConfirmation == index {
                    Text(LocalizedString("Delete", comment: "Test for table cell delete button"))
                        .lineLimit(1)
                        .foregroundColor(.white)
                        .background(
                            // Expand into margins
                            Color.red.padding(-12)
                        )
                        .transition(AnyTransition.move(edge: .trailing).combined(with: .opacity))
                        .offset(x: 4) // Push into margin
                        .onTapGesture {
                            withAnimation {
                                self.tableDeletionState = .enabled
                                self.delete()
                            }
                        }
                }
            }
        }
    }
}

private struct DeletionIndicator: View {
    var body: some View {
        Text("－")
            .bold()
            .foregroundColor(.white)
            .padding(1)
            .background(Circle().fill(Color.red))
            .padding(-1) // Prevent circle background from affecting layout
    }
}
