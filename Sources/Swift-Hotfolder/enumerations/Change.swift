//
//  Change.swift
//  Hotfolder
//
//  Created by Christoph Rohde on 15.08.24.
//

import Foundation

public enum Change {
    case created(URL)
    case modified(URL)
    case deleted(URL)
}
