//
//  WatcherConfigError.swift
//  Hotfolder_Framework
//
//  Created by Christoph Rohde on 15.08.24.
//

import Foundation

public enum WatcherConfigError: LocalizedError {
    case watcherIntervalTooShort(String)
    case maxHotfolderCountTooSmall(String)
    case jsonFileNotFound(String)
    case jsonParsingError(String)

    public var errorDescription: String? {
        switch self {
        case .watcherIntervalTooShort(let message),
             .maxHotfolderCountTooSmall(let message),
             .jsonFileNotFound(let message),
             .jsonParsingError(let message):
            return message
        }
    }
}
