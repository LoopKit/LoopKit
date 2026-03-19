//
//  TranscriptParagraph.swift
//  Loop
//
//  Created by Cameron Ingham on 7/16/25.
//

import Foundation

public struct TranscriptParagraph: Equatable, Hashable, RawRepresentable {
    
    public let excerpts: [TranscriptExcerpt]
    
    public var rawValue: String {
        excerpts.map(\.rawValue).joined(separator: " ")
    }
    
    public init(excepts: [TranscriptExcerpt]) {
        self.excerpts = excepts
    }
    
    public init(rawValue: String) {
        self.init(
            excepts: rawValue
                .split(separator: " [")
                .map({
                    let string = String($0)
                    if !string.hasPrefix("[") {
                        return "[\(string)"
                    } else {
                        return string
                    }
                })
                .compactMap({ TranscriptExcerpt(rawValue: $0) })
        )
    }
}
