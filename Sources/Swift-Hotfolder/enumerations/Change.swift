//
//  Change.swift
//  Hotfolder
//
//  Created by Christoph Rohde on 15.08.24.
//

import Foundation

public enum Change {
    case created(File)
    case modified(File)
    case deleted(File)

    public struct File {
        public let path: String
        public let hotfolderPath: String
    }
}
