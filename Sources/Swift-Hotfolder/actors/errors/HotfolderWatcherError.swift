//
//  HotfolderWatcherError.swift
//  Hotfolder
//
//  Created by Christoph Rohde on 15.08.24.
//

import Foundation

enum HotfolderWatcherError: Error {
    case hotfolderCantBeCreated(String)
    case maxHotfolderCountReached(String)
}
