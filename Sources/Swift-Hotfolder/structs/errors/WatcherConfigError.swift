//
//  WatcherConfigError.swift
//  Hotfolder_Framework
//
//  Created by Christoph Rohde on 15.08.24.
//

import Foundation

public enum WatcherConfigError: Error {
    case watcherIntervalToShort(String)
    case maxHotfolderCountToSmall(String)
    case jsonFileNotFound(String)
    case jsonParsingError(String)
}
