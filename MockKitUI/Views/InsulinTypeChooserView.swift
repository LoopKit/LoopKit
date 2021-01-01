//
//  InsulinTypeChooserView.swift
//  MockKitUI
//
//  Created by Pete Schwamb on 12/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI

public enum InsulinTypeChooserViewMode {
    case inFlow
    case detail
}

public struct InsulinTypeChooserView: View {
    @Environment(\.appName) private var appName
    @Environment(\.dismiss) var dismiss
    
    @State private var insulinType: InsulinType {
        didSet {
            didChange(insulinType)
        }
    }
    
    private var didChange: (InsulinType) -> Void
    
    let supportedInsulinTypes: [InsulinType]
    let mode: InsulinTypeChooserViewMode
    
    public init(initialValue: InsulinType, supportedInsulinTypes: [InsulinType], mode: InsulinTypeChooserViewMode, didChange: @escaping (InsulinType) -> Void) {
        self.supportedInsulinTypes = supportedInsulinTypes
        self.mode = mode
        self.didChange = didChange
        self._insulinType = State(initialValue: initialValue)
    }

    public var body: some View {
        switch mode {
        case .detail: return AnyView(content)
        case .inFlow: return AnyView(content)
        }
    }
    
    var content: some View {
        List {
            Section {
                
                insulinModelSettingDescription
                    .font(.callout)
                    .foregroundColor(Color(.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(4)
                    .padding(.top, 4)

                CheckmarkListItem(
                    title: Text(InsulinType.novolog.title),
                    description: Text(InsulinType.novolog.description),
                    isSelected: isSelected(.novolog)
                )
                .padding(.vertical, 4)

                CheckmarkListItem(
                    title: Text(InsulinType.humalog.title),
                    description: Text(InsulinType.humalog.description),
                    isSelected: isSelected(.humalog)
                )
                .padding(.vertical, 4)
                
                CheckmarkListItem(
                    title: Text(InsulinType.apidra.title),
                    description: Text(InsulinType.apidra.description),
                    isSelected: isSelected(.apidra)
                )
                .padding(.vertical, 4)
                
                if supportedInsulinTypes.contains(.fiasp) {
                    CheckmarkListItem(
                        title: Text(InsulinType.fiasp.title),
                        description: Text(InsulinType.fiasp.description),
                        isSelected: isSelected(.fiasp)
                    )
                    .padding(.vertical, 4)
                }
            }
            .buttonStyle(PlainButtonStyle()) // Disable row highlighting on selection
        }
        .insetGroupedListStyle()
    }
    
    var insulinModelSettingDescription: Text {
        let spellOutFormatter = NumberFormatter()
        spellOutFormatter.numberStyle = .spellOut
        return Text(String(format: LocalizedString("%1$@ calculates insulin activity over time based on the type of insulin you are using. You can choose from the following types of insulin.", comment: "Insulin type setting description (1: app name)"), appName))
    }
    
    private var doneButton: some View {
        Button(action: { self.dismiss() } ) { Text(LocalizedString("Done", comment: "Done editing button title")) }
    }
    
    private func isSelected(_ insulinType: InsulinType) -> Binding<Bool> {
        Binding(
            get: { self.insulinType == insulinType },
            set: { isSelected in
                if isSelected {
                    self.insulinType = insulinType
                }
            }
        )
    }

}

struct InsulinTypeChooser_Previews: PreviewProvider {
    static var previews: some View {
        InsulinTypeChooserView(initialValue: .apidra, supportedInsulinTypes: InsulinType.allCases, mode: .inFlow) { (newType) in
            print("New type = \(newType)")
        }
    }
}
