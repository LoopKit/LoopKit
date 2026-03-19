//
//  TranscriptExcerpt.swift
//  Loop
//
//  Created by Cameron Ingham on 7/16/25.
//

import Foundation

public struct TranscriptExcerpt: Equatable, Hashable, RawRepresentable {
    
    public let startTime: TimeInterval
    public let text: String
    
    public var rawValue: String {
        "[\(startTime.timecode(for: .transcript))] \(text)"
    }
    
    public init(startTime: TimeInterval, text: String) {
        self.startTime = startTime
        self.text = text
    }
    
    public init?(rawValue: String) {
        let fragments = rawValue.dropFirst().split(separator: "] ")
        self.startTime = TimeInterval(timecode: String(fragments[0]), style: .transcript)!
        self.text = String(fragments[1])
    }
}
