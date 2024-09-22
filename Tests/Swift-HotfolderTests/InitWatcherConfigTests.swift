//
//  Hotfolder_FrameworkTests.swift
//  Hotfolder_FrameworkTests
//
//  Created by Christoph Rohde on 15.08.24.
//

@testable import Swift_Hotfolder
import XCTest

final class InitWatcherConfigTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testInitWatcherConfigWithJsonFile() {
        let bundle = Bundle.module

        guard let pathToWatcherConfig = bundle.path(forResource: "watcher_config", ofType: "json") else {
            print("watcher_config.json not found")
            XCTAssertNotNil(nil)
            return
        }
        print(pathToWatcherConfig)

        let loadingResult = WatcherConfig.load(from: pathToWatcherConfig)

        guard let watcherConfigFromJson = try? loadingResult.get() else {
            if case .failure(let error) = loadingResult {
                print("""
                Error in 'InitWatcherConfigTests.testInitWatcherConfigWithJsonFile()':
                \(error)
                """)
            }
            return
        }

        // Expected
        let expectedHotfolderCount: UInt16 = 7

        // Current
        let currentHotfolderCount = watcherConfigFromJson.maxHotfolderCount

        XCTAssertEqual(expectedHotfolderCount, currentHotfolderCount)
    }

    func testInitWatcherConfigWithFallback() {
        let loadingResult = WatcherConfig.load()

        guard let watcherConfigFromFallBack = try? loadingResult.get() else {
            if case .failure(let error) = loadingResult {
                print("""
                Error in 'InitWatcherConfigTests.testInitWatcherConfigWithFallback()':
                \(error)
                """)
            }
            return
        }

        XCTAssertNotNil(watcherConfigFromFallBack)

        // Expected
        let expectedCreateFolderIfNotExist = true
        let expectedWatcherInterval = 1.0
        let expectedHotfolderCount: UInt16 = 5

        // Current
        let currentCreateFolderIfNotExists = watcherConfigFromFallBack.createNonExistingFolders
        let currentWatcherInterval = watcherConfigFromFallBack.watchInterval
        let currentHotfolderCount = watcherConfigFromFallBack.maxHotfolderCount

        XCTAssertEqual(expectedCreateFolderIfNotExist, currentCreateFolderIfNotExists)
        XCTAssertEqual(expectedWatcherInterval, currentWatcherInterval)
        XCTAssertEqual(expectedHotfolderCount, currentHotfolderCount)
    }

    func testInitWatcherConfigWithDefault() {
        let watcherConfigFromDefault = WatcherConfig.default

        XCTAssertNotNil(watcherConfigFromDefault)

        // Expected
        let expectedCreateFolderIfNotExist = true
        let expectedWatcherInterval = 1.0
        let expectedHotfolderCount: UInt16 = 5

        // Current
        let currentCreateFolderIfNotExists = watcherConfigFromDefault.createNonExistingFolders
        let currentWatcherInterval = watcherConfigFromDefault.watchInterval
        let currentHotfolderCount = watcherConfigFromDefault.maxHotfolderCount

        XCTAssertEqual(expectedCreateFolderIfNotExist, currentCreateFolderIfNotExists)
        XCTAssertEqual(expectedWatcherInterval, currentWatcherInterval)
        XCTAssertEqual(expectedHotfolderCount, currentHotfolderCount)
    }

    func testInitWatcherConfigWithParameters() {
        guard let watcherConfigFromParameters = try! WatcherConfig(
            createNonExistingFolders: false,
            watchInterval: 0.8,
            maxHotfolderCount: 260
        )
        else {
            XCTAssertNotNil(nil)
            return
        }

        // Expected
        let expectedCreateFolderIfNotExist = false
        let expectedWatcherInterval = 0.8
        let expectedHotfolderCount: UInt16 = 260

        XCTAssertEqual(expectedCreateFolderIfNotExist, watcherConfigFromParameters.createNonExistingFolders)
        XCTAssertEqual(expectedWatcherInterval, watcherConfigFromParameters.watchInterval)
        XCTAssertEqual(expectedHotfolderCount, watcherConfigFromParameters.maxHotfolderCount)
    }

    func testToSmallWatcherIntervalAssert() {
        XCTAssertThrowsError(
            try WatcherConfig(watchInterval: 0.01)
        )
    }

    func testToSmallHotfolderCountAssert() {
        XCTAssertThrowsError(
            try WatcherConfig(maxHotfolderCount: 0)
        )
    }
}
