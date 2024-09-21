//
//  File.swift
//
//
//  Created by Christoph Rohde on 07.09.24.
//

import Foundation

extension FileManager.DirectoryEnumerationOptions: Codable {
    // Encode DirectoryEnumerationOptions as its raw value (UInt)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }

    // Decode DirectoryEnumerationOptions from its raw value (UInt)
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(UInt.self)
        self.init(rawValue: rawValue)
    }
}
