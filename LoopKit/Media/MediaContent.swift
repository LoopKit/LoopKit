//
//  MediaContent.swift
//  Loop
//
//  Created by Cameron Ingham on 2/27/25.
//

import AVFoundation
import Foundation

public struct MediaContent: Equatable, Hashable, Identifiable {
    
    public struct StaticImage: Hashable {
        public let name: String
        public let bundle: Bundle
    }
    
    public let fileName: String
    public let metadata: Metadata
    public let staticImage: StaticImage
    public let animation: URL
    public let audio: URL
    public let transcript: Transcript?
    public let closedCaptions: ClosedCaptions
    
    public let asset: AVAsset
    
    public init(_ name: String, bundle: Bundle?) {
        self.fileName = name
        self.metadata = Metadata(url: (bundle ?? Bundle.main).url(forResource: name, withExtension: "json")!)!
        self.staticImage = StaticImage(name: name, bundle: bundle ?? Bundle.main)
        self.animation = (bundle ?? Bundle.main).url(forResource: name, withExtension: "mp4")!
        self.audio = (bundle ?? Bundle.main).url(forResource: name, withExtension: "mp3")!
        self.transcript = Transcript(url: (bundle ?? Bundle.main).url(forResource: name, withExtension: "txt")!)
        self.closedCaptions = ClosedCaptions(url: (bundle ?? Bundle.main).url(forResource: name, withExtension: "srt")!)
        
        self.asset = AVAsset(url: audio)
    }
    
    public var duration: TimeInterval {
        get async throws {
            try await asset.load(.duration).seconds
        }
    }
    
    public var id: Int {
        hashValue
    }
}
