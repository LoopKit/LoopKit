//
//  Metadata.swift
//  Loop
//
//  Created by Cameron Ingham on 8/11/25.
//

import Foundation

public struct Metadata: Equatable, Hashable, Decodable {
    public let title: String
    public let author: String
    
    public init?(url: URL) {
        do {
            let metadata = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
            self.title = metadata.title
            self.author = metadata.author
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
}
