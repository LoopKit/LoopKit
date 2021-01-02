//
//  InsulinTypeSetting.swift
//  MockKitUI
//
//  Created by Pete Schwamb on 1/1/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct InsulinTypeSetting: View {
    
    @State private var insulinType: InsulinType
    private var supportedInsulinTypes: [InsulinType]
    private var didChange: (InsulinType) -> Void
    
    
    public init(initialValue: InsulinType, supportedInsulinTypes: [InsulinType], didChange: @escaping (InsulinType) -> Void) {
        self._insulinType = State(initialValue: initialValue)
        self.supportedInsulinTypes = supportedInsulinTypes
        self.didChange = didChange
    }
    
    public var body: some View {
        List {
            Section {
                InsulinTypeChooser(insulinType: insulinTypeBinding, supportedInsulinTypes: supportedInsulinTypes)
            }
            .buttonStyle(PlainButtonStyle()) // Disable row highlighting on selection
        }
        .insetGroupedListStyle()

    }
    
    private var insulinTypeBinding: Binding<InsulinType> {
        Binding(
            get: { self.insulinType },
            set: { newValue in
              insulinType = newValue
              didChange(newValue)
            }
        )
    }
}

struct InsulinTypeSetting_Previews: PreviewProvider {
    static var previews: some View {
        InsulinTypeSetting(initialValue: .humalog, supportedInsulinTypes: InsulinType.allCases) { (newType) in
            
        }
    }
}
