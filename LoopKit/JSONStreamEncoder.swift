//
//  JSONStreamEncoder.swift
//  LoopKit
//
//  Created by Darin Krauss on 6/25/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public enum JSONStreamEncoderError: Error {
    case encoderClosed
}

public class JSONStreamEncoder {
    private let stream: DataOutputStream
    private var encoded: Bool
    private var closed: Bool

    public init(stream: DataOutputStream) {
        self.stream = stream
        self.encoded = false
        self.closed = false
    }

    public func close() -> Error? {
        guard !closed else {
            return nil
        }

        self.closed = true

        do {
            try stream.write(encoded ? "\n]" : "[]")
        } catch let error {
            return error
        }

        return nil
    }

    public func encode<T>(_ values: T) throws where T: Collection, T.Element: Encodable {
        guard !closed else {
            throw JSONStreamEncoderError.encoderClosed
        }

        for value in values {
            do {
                let encodedData = try Self.encoder.encode(value)
                try stream.write(encoded ? ",\n" : "[\n")
                try stream.write(encodedData)
                encoded = true
            } catch {
                // Log the error and insert a placeholder or error message in the JSON
                print("Failed to encode value: \(value) with error: \(error.localizedDescription)")
                let errorInfo = try Self.encoder.encode(["error": "Failed to encode value: \(value) due to: \(error.localizedDescription)"])
                try stream.write(encoded ? ",\n" : "[\n")
                try stream.write(errorInfo)
                encoded = true
            }
        }
    }

    private static var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        if #available(watchOSApplicationExtension 6.0, *) {
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        encoder.dateEncodingStrategy = .custom { (date, encoder) in
            var encoder = encoder.singleValueContainer()
            try encoder.encode(dateFormatter.string(from: date))
        }
        return encoder
    }()

    private static let dateFormatter: ISO8601DateFormatter = {
        var dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return dateFormatter
    }()
}
