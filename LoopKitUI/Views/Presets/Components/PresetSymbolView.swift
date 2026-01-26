//
//  PresetSymbolView.swift
//  Loop
//
//  Created by Cameron Ingham on 8/20/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI

public struct PresetSymbolView: View {
    
    @Environment(\.colorPalette) private var colorPalette
    
    let symbol: PresetSymbol
    let iconSize: Double
    
    public init(_ symbol: PresetSymbol, iconSize: Double = 17) {
        self.symbol = symbol
        self.iconSize = iconSize
    }
    
    public var body: some View {
        Group {
            switch symbol.symbolType {
            case .emoji:
                Text(symbol.value)
                    .font(.system(size: UIFontMetrics.default.scaledValue(for: iconSize - 2)))
            case .image:
                Text(Image(symbol.value))
                    .foregroundStyle(Color(presetSymbolTint: symbol.tint, palette: colorPalette))
                    .font(.system(size: UIFontMetrics.default.scaledValue(for: iconSize)))
            case .systemImage:
                Text(Image(systemName: symbol.value))
                    .foregroundStyle(Color(presetSymbolTint: symbol.tint, palette: colorPalette))
                    .font(.system(size: UIFontMetrics.default.scaledValue(for: iconSize)))
            }
        }
        .fontDesign(.monospaced)
    }
}

#Preview {
    PresetSymbolView(.emoji("🍎"), iconSize: 22)
}
