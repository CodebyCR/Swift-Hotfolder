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


    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testNonExistingHotfolderCreation() {
        let watcher: HotfolderWatcher = .shared
//        var cancellables: Set<AnyCancellable>  = []
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

//    func testTimingVaration() {
//        XCTAssertTrue()
//    }
//
//    func testMaxHotfolderOvershot() {
//        XCTAssertThrows()
//    }

    fileprivate func create(_ testFile: URL) {
//        try? FileManager.default.createDirectory(atPath: testFile.deletingLastPathComponent().absoluteString, withIntermediateDirectories: true, attributes: nil)
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
    
    func testReceiveChangeEvent(){
        // preapare
        let watcher: HotfolderWatcher = .shared
        var cancellables: Set<AnyCancellable>  = []
        let fileManager = FileManager.default
        let tempDirectory = fileManager.homeDirectoryForCurrentUser
            .appending(component: "Hotfolder_Test")
            .appending(component: UUID().uuidString)

        let hotfolder = Hotfolder(at: tempDirectory)
        let createExpectaion = XCTestExpectation(description: "Create event received.")
        let modifyExpectaion = XCTestExpectation(description: "Modify event received.")
        let deleteExpectaion = XCTestExpectation(description: "Delete event received.")

        hotfolder.modifySubject.sink { modifiedUrl in
            modifyExpectaion.fulfill()
            print("modified")
        }.store(in: &cancellables)

        hotfolder.deleteSubject.sink { deletedUrl in
            deleteExpectaion.fulfill()
            print("deleted")
        }.store(in: &cancellables)

        hotfolder.createSubject.sink { createdUrl in
            createExpectaion.fulfill()
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

        wait(for: [createExpectaion, modifyExpectaion, deleteExpectaion], timeout: 6.0)
    }
}
