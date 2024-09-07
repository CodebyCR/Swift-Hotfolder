//
//  HotfolderWatcher.swift
//  Hotfolder
//
//  Created by Christoph Rohde on 10.08.24.
//

import Combine
import Foundation

@globalActor
public actor HotfolderWatcher: GlobalActor {
    private var hotfolders: Set<Hotfolder> = []
    private let fileManager = FileManager.default
    private let config = WatcherConfig.default
    private var task: Task<Void, Error>?

    private init() {}

    public static let shared = HotfolderWatcher()

    @discardableResult
    public func add(_ hotfolder: consuming Hotfolder) -> Result<Bool, Error> {
        guard hotfolders.count < config.maxHotfolderCount else {
            return .failure(HotfolderWatcherError.maxHotfolderCountReached("Max hotfolder count reached"))
        }

        if config.createNonExistingFolders, !fileManager.fileExists(atPath: hotfolder.path.path) {
            do {
                try fileManager.createDirectory(at: hotfolder.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return .failure(HotfolderWatcherError.hotfolderCantBeCreated("Hotfolder can't be created"))
            }
        }

        let (inserted, _) = hotfolders.insert(hotfolder)
        return .success(inserted)
    }

    public func startWatching() async throws {
        var knownFiles: [Hotfolder: [String: Date]] = [:]

        while true {
            try await Task.sleep(nanoseconds: UInt64(config.watchInterval * 1_000_000_000.0))
            for hotfolder in hotfolders {
                if knownFiles[hotfolder] == nil {
                    knownFiles[hotfolder] = try await initializeKnownFiles(for: hotfolder)
                }
                let currentFiles = try getCurrentFiles(for: hotfolder)
                try await checkForChanges(hotfolder: hotfolder, currentFiles: currentFiles, knownFiles: &knownFiles[hotfolder]!)
                try await checkForDeletions(hotfolder: hotfolder, currentFiles: currentFiles, knownFiles: &knownFiles[hotfolder]!)
            }
        }
    }

    private func initializeKnownFiles(for hotfolder: Hotfolder) async throws -> [String: Date] {
        var knownFiles: [String: Date] = [:]
        let enumerator = fileManager.enumerator(atPath: hotfolder.path.path)
        while let filePath = enumerator?.nextObject() as? String {
            let fullPath = (hotfolder.path.path as NSString).appendingPathComponent(filePath)
            if let attributes = try? fileManager.attributesOfItem(atPath: fullPath),
               let modificationDate = attributes[.modificationDate] as? Date
            {
                knownFiles[filePath] = modificationDate
            }
        }
        return knownFiles
    }

    private func getCurrentFiles(for hotfolder: Hotfolder) throws -> [String] {
        return fileManager.enumerator(atPath: hotfolder.path.path)?.allObjects as? [String] ?? []
    }

    private func checkForChanges(hotfolder: Hotfolder, currentFiles: [String], knownFiles: inout [String: Date]) async throws {
        for filePath in currentFiles {
            let fullPath = (hotfolder.path.path as NSString).appendingPathComponent(filePath)
            if let attributes = try? fileManager.attributesOfItem(atPath: fullPath),
               let modificationDate = attributes[.modificationDate] as? Date
            {
                if let knownDate = knownFiles[filePath] {
                    if modificationDate != knownDate {
                        knownFiles[filePath] = modificationDate
                        await hotfolder.modifySubject.send(URL(fileURLWithPath: fullPath))
                    }
                } else {
                    knownFiles[filePath] = modificationDate
                    await hotfolder.createSubject.send(URL(fileURLWithPath: fullPath))
                }
            }
        }
    }

    private func checkForDeletions(hotfolder: Hotfolder, currentFiles: [String], knownFiles: inout [String: Date]) async throws {
        for (filePath, _) in knownFiles {
            if !currentFiles.contains(filePath) {
                knownFiles.removeValue(forKey: filePath)
                await hotfolder.deleteSubject.send(URL(fileURLWithPath: (hotfolder.path.path as NSString).appendingPathComponent(filePath)))
            }
        }
    }
}
