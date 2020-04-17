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
    var isSaveButtonEnabled: Bool
    var cards: CardStack
    var actionAreaContent: ActionAreaContent
    var save: () -> Void

    public init(
        title: Text,
        isSaveButtonEnabled: Bool = true,
        @CardStackBuilder cards: () -> CardStack,
        @ViewBuilder actionAreaContent: () -> ActionAreaContent,
        onSave save: @escaping () -> Void
    ) {
        self.title = title
        self.isSaveButtonEnabled = isSaveButtonEnabled
        self.cards = cards()
        self.actionAreaContent = actionAreaContent()
        self.save = save
    }

    public var body: some View {
        VStack(spacing: 0) {
            CardList(title: title, content: cards)

            VStack {
                actionAreaContent
                    .padding(.top)

                Button(
                    action: save,
                    label: {
                        Text("Save", comment: "The button text for saving on a configuration page")
                    }
                )
                .buttonStyle(ActionButtonStyle(.primary))
                .disabled(!isSaveButtonEnabled)
                .padding()
            }
            .padding(.bottom) // FIXME: unnecessary on iPhone 8 size devices
            .background(Color(.systemBackground).shadow(radius: 5))
        }
        .edgesIgnoringSafeArea(.bottom)
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
