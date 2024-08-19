//
//  HotfolderWatcher.swift
//  Hotfolder
//
//  Created by Christoph Rohde on 10.08.24.
//

import Foundation

public actor HotfolderWatcher {
    private var hotfolders: Set<Hotfolder> = []
    private let fileManager = FileManager.default
    private let config: WatcherConfig

    public init(config: consuming WatcherConfig = .default) {
        self.config = config
    }

    public func add(hotfolder: consuming Hotfolder) -> Result<Bool, Error> {
        guard hotfolders.count < config.maxHotfolderCount else {
            return .failure(HotfolderWatcherError.maxHotfolderCountReached("""
            Can't insert Hotfolder with path \(hotfolder.path).
            Your current Hotfolder limited (\(config.maxHotfolderCount)) is reached.
            You could increase this count in the given 'WatcherConfig' if needed.
            """))
        }

        if config.createNonExistingFolders, !fileManager.fileExists(atPath: hotfolder.path) {
            do {
                try fileManager.createDirectory(atPath: hotfolder.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return .failure(HotfolderWatcherError.hotfolderCantBeCreated("""
                The given Hotfolder with path \(hotfolder.path) can't be created.
                Please check your permissions for this path and your application.
                """))
            }
        }

        let (hotfolderInserted, _) = hotfolders.insert(hotfolder)

        return .success(hotfolderInserted)
    }

    public func watch(handler: @escaping (Change) async throws -> Void) async throws {
        let stream = AsyncThrowingStream<Change, Error> { continuation in
            Task {
                do {
                    var knownFiles: [Hotfolder: [String: Date]] = [:]

                    while true {
                        try await Task.sleep(nanoseconds: UInt64(config.watchInterval * 1_000_000_000.0))

                        for hotfolder in hotfolders {
                            if knownFiles[hotfolder] == nil {
                                knownFiles[hotfolder] = try await initializeKnownFiles(for: hotfolder)
                            }

                            let currentFiles = try getCurrentFiles(for: hotfolder)

                            try await checkForChanges(hotfolder: hotfolder, currentFiles: currentFiles, knownFiles: &knownFiles[hotfolder]!, continuation: continuation)

                            try await checkForDeletions(hotfolder: hotfolder, currentFiles: currentFiles, knownFiles: &knownFiles[hotfolder]!, continuation: continuation)
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }

        for try await change in stream {
            try await handler(change)
        }
    }

    private func initializeKnownFiles(for hotfolder: Hotfolder) async throws -> [String: Date] {
        var knownFiles: [String: Date] = [:]
        let enumerator = fileManager.enumerator(atPath: hotfolder.path)
        while let filePath = enumerator?.nextObject() as? String {
            let fullPath = (hotfolder.path as NSString).appendingPathComponent(filePath)
            if let attributes = try? fileManager.attributesOfItem(atPath: fullPath),
               let modificationDate = attributes[.modificationDate] as? Date
            {
                knownFiles[filePath] = modificationDate
            }
        }
        return knownFiles
    }

    private func getCurrentFiles(for hotfolder: Hotfolder) throws -> [String] {
        return fileManager.enumerator(atPath: hotfolder.path)?.allObjects as? [String] ?? []
    }

    private func checkForChanges(hotfolder: Hotfolder, currentFiles: [String], knownFiles: inout [String: Date], continuation: AsyncThrowingStream<Change, Error>.Continuation) async throws {
        for filePath in currentFiles {
            let fullPath = (hotfolder.path as NSString).appendingPathComponent(filePath)
            if let attributes = try? fileManager.attributesOfItem(atPath: fullPath),
               let modificationDate = attributes[.modificationDate] as? Date
            {
                if let knownDate = knownFiles[filePath] {
                    if modificationDate != knownDate {
                        continuation.yield(.modified(Change.File(path: filePath, hotfolderPath: hotfolder.path)))
                        knownFiles[filePath] = modificationDate
                    }
                } else {
                    continuation.yield(.created(Change.File(path: filePath, hotfolderPath: hotfolder.path)))
                    knownFiles[filePath] = modificationDate
                }
            }
        }
    }

    private func checkForDeletions(hotfolder: Hotfolder, currentFiles: [String], knownFiles: inout [String: Date], continuation: AsyncThrowingStream<Change, Error>.Continuation) async throws {
        for (filePath, _) in knownFiles {
            if !currentFiles.contains(filePath) {
                continuation.yield(.deleted(Change.File(path: filePath, hotfolderPath: hotfolder.path)))
                knownFiles.removeValue(forKey: filePath)
            }
        }
    }
}
