//
//  ClosedCaptionFragment.swift
//  Loop
//
//  Created by Cameron Ingham on 2/27/25.
//

import Foundation

public struct ClosedCaptionFragment: Equatable, Hashable, RawRepresentable {
    
    public let sequenceNumber: Int
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    
    public var rawValue: String {
        """
        \(sequenceNumber)
        \(String(describing: startTime.timecode)) --> \(String(describing: endTime.timecode))
        \(text)
        """
    }
    
    public init?(rawValue: String) {
        let rawFragments = rawValue.split(separator: "\n")
        self.sequenceNumber = Int(rawFragments[0])!
        let timecodes = rawFragments[1].split(separator: " --> ")
        self.startTime = TimeInterval(timecode: String(timecodes[0]), style: .caption)!
        self.endTime = TimeInterval(timecode: String(timecodes[1]), style: .caption)!
        self.text = String(rawFragments[2])
    }
}
