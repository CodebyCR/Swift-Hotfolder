//
//  WatcherConfig.swift
//  Hotfolder
//
//  Created by Christoph Rohde on 10.08.24.
//

import Foundation

public struct WatcherConfig: Codable {
    let createNonExistingFolders: Bool
    let watchInterval: Double
    let maxHotfolderCount: UInt16

    enum CodingKeys: String, CodingKey {
        case createNonExistingFolders = "create_non_existing_folders"
        case watchInterval = "watch_interval"
        case maxHotfolderCount = "max_hotfolder_count"
    }

    /// For the **safe** default one.
    private init() {
        self.createNonExistingFolders = true
        self.watchInterval = 1.0
        self.maxHotfolderCount = 5
    }

    public static let `default` = WatcherConfig()

    /// For maybe **unsafe** WatcherConfig created be the user of the framework.
    public init?(createNonExistingFolders: Bool, watchInterval: Double, maxHotfolderCount: UInt16) throws {
        let minWatcherInterval = 0.1
        guard watchInterval >= minWatcherInterval else {
            throw WatcherConfigError.watcherIntervalToShort("Your watcherInterval is to short ( < 0.01). Set it up to avoid unexpeted overlabs.")
        }

        guard maxHotfolderCount >= 1 else {
            throw WatcherConfigError.maxHotfolderCountToSmall("Your maxHotfolderCount is smaller than '1' which make no sense.")
        }

        self.createNonExistingFolders = createNonExistingFolders
        self.watchInterval = watchInterval
        self.maxHotfolderCount = maxHotfolderCount
    }

    /// Try to read the given path to a config json file or return the 'default' WatcherConfig.
    public static func load(from configJsonPath: String = "") -> Result<WatcherConfig, WatcherConfigError> {
        guard !configJsonPath.isEmpty else {
            print("Info: No 'configJsonPath' given. Using default configuration.")
            return .success(.default)
        }

        guard let configData = FileManager.default.contents(atPath: configJsonPath) else {
            return .failure(WatcherConfigError.jsonFileNotFound("Config file not found."))
        }

        do {
            return try .success(JSONDecoder().decode(WatcherConfig.self, from: configData))
        } catch {
            return .failure(WatcherConfigError.jsonParsingError("Failed to parse watcher config file at \(configJsonPath)."))
        }
    }
}
