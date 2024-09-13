//
//  File.swift
//
//
//  Created by Christoph Rohde on 07.09.24.
//

import Foundation

extension FileManager.DirectoryEnumerationOptions: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}
