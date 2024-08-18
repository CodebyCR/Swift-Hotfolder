//
//  Change.swift
//  Hotfolder
//
//  Created by Christoph Rohde on 15.08.24.
//

import Foundation

enum Change {
    case created(File)
    case modified(File)
    case deleted(File)

    struct File {
        let path: String
        let hotfolderPath: String
    }
}
