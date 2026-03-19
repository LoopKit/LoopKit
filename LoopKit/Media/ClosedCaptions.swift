//
//  ClosedCaptions.swift
//  Loop
//
//  Created by Cameron Ingham on 2/27/25.
//

import Foundation

public struct ClosedCaptions: Equatable, Hashable, RawRepresentable {
    
    public var fragments: [ClosedCaptionFragment]
    
    public var rawValue: String {
        fragments.map(\.rawValue).joined(separator: "\n\n")
    }
    
    public init(fragments: [ClosedCaptionFragment]) {
        self.fragments = fragments
    }
    
    public init(url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            assertionFailure("Could not generate data from file at URL: \(url.absoluteString)")
            self.init(fragments: [])
            return
        }
        
        let rawValue = String(data: data, encoding: .utf8)!
        self.init(rawValue: rawValue)
    }
    
    public init(rawValue: String) {
        self.fragments = rawValue.split(separator: "\n\n").compactMap {
            ClosedCaptionFragment(rawValue: String($0))
        }
    }
    
    public func currentFragment(at timecode: TimeInterval) -> ClosedCaptionFragment? {
        fragments.first(where: { timecode >= $0.startTime && timecode < $0.endTime })
    }
}
