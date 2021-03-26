//
//  DeliveryUncertaintyRecoveryView.swift
//  MockKitUI
//
//  Created by Pete Schwamb on 8/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct DeliveryUncertaintyRecoveryView: View, HorizontalSizeClassOverride {
    @Environment(\.dismiss) private var dismiss

    let appName: String
    let uncertaintyStartedAt: Date
    let recoverCommsTapped: () -> Void
    
    var body: some View {
        NavigationView {
            GuidePage(content: {
                Text("\(self.appName) has been unable to communicate with the Simulator Pump since \(self.uncertaintyDateLocalizedString).\n\nWithout communication, the app cannot continue to send commands for insulin delivery or display accurate, recent information about your active insulin or the insulin being delivered.")
            }) {
                Button(action: {
                    self.recoverCommsTapped()
                    self.dismiss()
                }) {
                    Text(LocalizedString("Recover Simulator", comment: "Button title recovering comms"))
                    .actionButtonStyle()
                    .padding()
                }
            }
            .environment(\.horizontalSizeClass, horizontalOverride)
            .navigationBarTitle(Text("Comms Recovery"), displayMode: .large)
            .navigationBarItems(leading: backButton)
        }
    }
    
    private var uncertaintyDateLocalizedString: String {
        DateFormatter.localizedString(from: uncertaintyStartedAt, dateStyle: .none, timeStyle: .short)
    }
    
    private var backButton: some View {
        Button(LocalizedString("Back", comment: "Back button text on DeliveryUncertaintyRecoveryView"), action: {
            self.dismiss()
        })
    }
}

struct DeliveryUncertaintyRecoveryView_Previews: PreviewProvider {
    static var previews: some View {
        DeliveryUncertaintyRecoveryView(appName: "Test App", uncertaintyStartedAt: Date()) {
            print("Recover Comms")
        }
    }
}


// Wrapper to provide a CompletionNotifying ViewController
class DeliveryUncertaintyRecoveryViewController: UIHostingController<AnyView>, CompletionNotifying {
    
    public weak var completionDelegate: CompletionDelegate?
    
    init(appName: String, uncertaintyStartedAt: Date, recoverCommsTapped: @escaping () -> Void) {
        
        var dismiss = {}
        
        let view = DeliveryUncertaintyRecoveryView(appName: appName, uncertaintyStartedAt: uncertaintyStartedAt) {
            recoverCommsTapped()
            dismiss()
        }
        .environment(\.dismiss, { dismiss() })
        
        super.init(rootView: AnyView(view))
        
        dismiss = {
            self.completionDelegate?.completionNotifyingDidComplete(self)
        }
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
