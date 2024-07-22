//
//  Callout.swift
//  LoopKitUI
//
//  Created by Cameron Ingham on 1/5/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct Callout<Content: View>: View {
    public enum Severity {
        case note
        case caution
        case warning
        
        var hasIcon: Bool {
            self != .note
        }
        
        var prefix: Text {
            switch self {
            case .note:
                return Text("Note: ")
            case .caution:
                return Text("Caution: ")
            case .warning:
                return Text("Warning: ")
            }
        }
        
        var color: Color {
            switch self {
            case .note:
                return .accentColor
            case .caution:
                return .orange
            case .warning:
                return .red
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .note:
                return color.opacity(0.15)
            case .caution:
                return color.opacity(0.05)
            case .warning:
                return color.opacity(0.05)
            }
        }
    }
    
    private let title: Text
    private let content: Content?
    private let severity: Severity
    
    public init(_ severity: Severity, title: Text, @ViewBuilder content: () -> Content) {
        self.severity = severity
        self.title = title
        self.content = content()
    }
    
    public init(_ severity: Severity, title: Text) where Content == EmptyView {
        self.severity = severity
        self.title = title
        self.content = nil
    }

    public init(_ severity: Severity, title: Text, message: Text) where Content == Text {
        self.title = title
        self.content = message
        self.severity = severity
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if severity.hasIcon {
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundColor(severity.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Group {
                    severity.prefix + title
                }
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                
                if let content {
                    VStack(alignment: .leading, spacing: 12) {
                        Group {
                            content
                        }
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(severity.backgroundColor)
    }
}

struct Callout_Previews: PreviewProvider {
    static var previews: some View {
        Callout(.note, title: Text("Lorem ipsum"))
        Callout(.caution, title: Text("Lorem ipsum"))
        Callout(.warning, title: Text("Lorem ipsum"))
    }
}
