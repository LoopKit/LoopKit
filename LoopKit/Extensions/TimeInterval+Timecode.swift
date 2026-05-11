//
//  TimeInterval+Timecode.swift
//  Loop
//
//  Created by Cameron Ingham on 2/27/25.
//

import Foundation

public extension TimeInterval {
    enum TimecodeStyle {
        case caption
        case transcript
        
        public var separator: String {
            switch self {
            case .caption:
                return ":,"
            case .transcript:
                return ":"
            }
        }
    }
    
    init?(timecode: String, style: TimecodeStyle) {
        self.init(timecode: timecode, separator: style.separator)
    }
    
    init?(timecode: String, separator: String) {
        let components = timecode.components(separatedBy: CharacterSet(charactersIn: separator))
            
        guard components.count >= 3,
              let hours = Int(components[0]),
              let minutes = Int(components[1]),
              let seconds = Int(components[2]) else {
            return nil
        }
        
        let totalSeconds = Double(hours * 3600 + minutes * 60 + seconds)
        
        var totalMilliseconds: Double = 0
        if components.count > 3, let milliseconds = Int(components[3]) {
            totalMilliseconds = Double(milliseconds) / 1000.0
        }
        
        self = totalSeconds + totalMilliseconds
    }
    
    func timecode(for style: TimecodeStyle) -> String {
        let totalSeconds = Int(self)
        let milliseconds = Int((self.truncatingRemainder(dividingBy: 1)) * 1000)
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds % 3600) / 60
        let hours = totalSeconds / 3600
        
        switch style {
        case .caption:
            return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
        case .transcript:
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}
