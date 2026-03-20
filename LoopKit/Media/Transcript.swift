//
//  Transcript.swift
//  Loop
//
//  Created by Cameron Ingham on 7/16/25.
//

import Foundation

public struct Transcript: Equatable, Hashable, RawRepresentable {
    
    public let paragraphs: [TranscriptParagraph]
    
    public var rawValue: String {
        paragraphs.map(\.rawValue).joined(separator: "\n\n")
    }
    
    public init(paragraphs: [TranscriptParagraph]) {
        self.paragraphs = paragraphs
    }
    
    public init(rawValue: String) {
        self.paragraphs = rawValue.split(separator: "\n\n").compactMap {
            TranscriptParagraph(rawValue: String($0))
        }
    }
    
    public init(url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            assertionFailure("Could not generate data from file at URL: \(url.absoluteString)")
            self.init(paragraphs: [])
            return
        }
        
        let rawValue = String(data: data, encoding: .utf8)!
        self.init(rawValue: rawValue)
    }
    
    public func currentExcerpt(at timecode: TimeInterval) -> TranscriptExcerpt {
        paragraphs.flatMap(\.excerpts).last(where: { $0.startTime <= timecode }) ?? TranscriptExcerpt(startTime: 0, text: "")
    }
}
