//
//  HotfolderWatcherError.swift
//  Hotfolder
//
//  Created by Christoph Rohde on 15.08.24.
//

import Foundation

enum HotfolderWatcherError: LocalizedError {
    case hotfolderCantBeCreated(String)
    case maxHotfolderCountReached(String)
    case hotfolderWatcherCurrentlyRun(String)

    public var errorDescription: String? {
        switch self {
        case
            .hotfolderCantBeCreated(let message),
            .maxHotfolderCountReached(let message),
            .hotfolderWatcherCurrentlyRun(let message):
            return message
        }
    }
}
