//
//  File.swift
//
//
//  Created by Christoph Rohde on 15.09.24.
//

@testable import Swift_Hotfolder
import XCTest
import Combine

final class HotfolderWatcherTests: XCTestCase {

    func testReceiveChangeEvent() async{
        // preapare
        let watcher: HotfolderWatcher = .shared
        await watcher.stop()
        try? await watcher.setup(.default)

        var cancellables: Set<AnyCancellable>  = []
        let fileManager = FileManager.default
        let tempDirectory = fileManager.homeDirectoryForCurrentUser
            .appending(component: "Hotfolder_Test")
            .appending(component: UUID().uuidString)

        let hotfolder = Hotfolder(at: tempDirectory)
        let createExpectation = XCTestExpectation(description: "Create event received.")
        let modifyExpectation = XCTestExpectation(description: "Modify event received.")
        let deleteExpectation = XCTestExpectation(description: "Delete event received.")

        hotfolder.modifySubject.sink { _ in
            modifyExpectation.fulfill()
            print("modified")
        }.store(in: &cancellables)

        hotfolder.deleteSubject.sink { _ in
            deleteExpectation.fulfill()
            print("deleted")
        }.store(in: &cancellables)

        hotfolder.createSubject.sink { _ in
            createExpectation.fulfill()
            print("created")
        }.store(in: &cancellables)

        let testFile = hotfolder.path.appendingPathComponent("Test_File.txt")
        print(testFile.path)

        Task {
            await watcher.add(hotfolder)
            do {
                try await watcher.startWatching()
            } catch {
                print(error)
            }
            try? await Task.sleep(for: .seconds(2))

            print("create")
            create(testFile)
            try? await Task.sleep(for: .seconds(1))

            print("modify")
            modify(testFile)
            try? await Task.sleep(for: .seconds(1))

            print("delete")
            delete(testFile)
            try? await Task.sleep(for: .seconds(1))
        }

        wait(for: [createExpectation, modifyExpectation, deleteExpectation], timeout: 6.0)
    }

    func testMaxHotfolderOvershot() async {
        let fileManager = FileManager.default
        let tempDirectory1 = fileManager.homeDirectoryForCurrentUser
            .appending(component: "Hotfolder_Test")
            .appending(component: UUID().uuidString)

        let tempDirectory2 = fileManager.homeDirectoryForCurrentUser
            .appending(component: "Hotfolder_Test")
            .appending(component: UUID().uuidString)

        let hotfolder1 = Hotfolder(at: tempDirectory1)
        let hotfolder2 = Hotfolder(at: tempDirectory2)

        guard let config = try? WatcherConfig(maxHotfolderCount: 1) else {
            print("Failed to create WatcherConfig")
            return
        }

        let watcher = HotfolderWatcher.shared
        do {
            try await watcher.setup(config)
        } catch {
            print(error)
        }

        let maxHotfolderCount = await watcher.watcherConfig.maxHotfolderCount
        print("Max Hotfolder Count: \(maxHotfolderCount)")

        await watcher.add(hotfolder1)
        let addResult = await watcher.add(hotfolder2)

        switch addResult {
        case .success(let succcess):
            XCTAssertFalse(succcess)

        case .failure(let error):
            XCTAssertNotNil(error)
        }

        Task {
            await watcher.remove(hotfolder1)
        }

    }

    func testNonExistingHotfolderCreation() {
        let watcher: HotfolderWatcher = .shared
        let tempDir = FileManager.default.temporaryDirectory
        let tempDirectory = tempDir.appendingPathComponent(UUID().uuidString)
        let hotfolder = Hotfolder(at: tempDirectory)


        // current
        Task {
            let result = await watcher.add(hotfolder)

            switch result {
            case .success(let added):
                XCTAssertTrue(added)
            case .failure(let error):
                print(error.localizedDescription)
                XCTAssertNoThrow(error)
            }

            await watcher.stop()
        }

        do {
            try FileManager.default.removeItem(at: hotfolder.path)
        } catch {
            print(error.localizedDescription)
            XCTAssertNoThrow(error)
        }
    }

    // Helper Methods

    fileprivate func create(_ testFile: URL) {
        if (FileManager.default.createFile(atPath: testFile.path, contents: nil , attributes: nil)) {
            print("File created successfully.")
        } else {
            print("File not created.")
        }
    }

    fileprivate func modify(_ testFile: URL) {
        let fileContent = "This is for a Test"
        do {
            try fileContent.data(using: .utf8)?.write(to: testFile)
        } catch{
            print(error.localizedDescription)
            XCTAssertNoThrow(error)
        }
    }

    fileprivate func delete(_ testFile: URL) {
        do {
            try FileManager.default.removeItem(at: testFile)
        } catch {
            print(error.localizedDescription)
            XCTAssertNoThrow(error)
        }
    }
}
