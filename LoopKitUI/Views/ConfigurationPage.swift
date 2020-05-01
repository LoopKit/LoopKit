//
//  ConfigurationPage.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct ConfigurationPage<ActionAreaContent: View>: View {
    var title: Text
    var actionButtonTitle: Text
    var isActionButtonEnabled: Bool
    var cards: CardStack
    var actionAreaContent: ActionAreaContent
    var action: () -> Void

    public init(
        title: Text,
        actionButtonTitle: Text,
        isActionButtonEnabled: Bool = true,
        @CardStackBuilder cards: () -> CardStack,
        @ViewBuilder actionAreaContent: () -> ActionAreaContent,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.actionButtonTitle = actionButtonTitle
        self.isActionButtonEnabled = isActionButtonEnabled
        self.cards = cards()
        self.actionAreaContent = actionAreaContent()
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 0) {
            CardList(title: title, content: cards)

            VStack {
                actionAreaContent
                    .padding(.top)

                Button(
                    action: action,
                    label: {
                        actionButtonTitle
                    }
                )
                .buttonStyle(ActionButtonStyle(.primary))
                .disabled(!isActionButtonEnabled)
                .padding()
            }
            .padding(.bottom) // FIXME: unnecessary on iPhone 8 size devices
            .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

extension ConfigurationPage {
    /// Convenience initializer for a page whose action is 'Save'
    public init(
        title: Text,
        isSaveButtonEnabled: Bool = true,
        @CardStackBuilder cards: () -> CardStack,
        @ViewBuilder actionAreaContent: () -> ActionAreaContent,
        onSave save: @escaping () -> Void
    ) {
        self.init(
            title: title,
            actionButtonTitle: Text("Save", comment: "The button text for saving on a configuration page"),
            isActionButtonEnabled: isSaveButtonEnabled,
            cards: cards,
            actionAreaContent: actionAreaContent,
            action: save
        )
    }
}

struct ConfigurationPage_Previews: PreviewProvider {
    static var previews: some View {
        ConfigurationPage(
            title: Text("Example"),
            cards: {
                Text("A simple card")
                Text("A card whose text will wrap onto multiple lines if I continue to type for long enough—this length should do")

                Card {
                    Text("Top component")
                    Text("Bottom component")
                }

                Card(of: 1...3, id: \.self) { value in
                    Text("Dynamic component #\(value)")
                }
            },
            actionAreaContent: {
                Text("Above the save button")
            },
            onSave: {}
        )
    }
}
