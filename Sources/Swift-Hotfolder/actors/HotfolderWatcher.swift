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

    init(config: consuming WatcherConfig = .default) {
        self.config = config
    }

    func add(hotfolder: consuming Hotfolder) -> Result<Bool, Error> {
        guard hotfolders.count >= config.maxHotfolderCount else {
            return .failure(HotfolderWatcherError.maxHotfolderCountReached("""
            Can't insert Hotfolder with path \(hotfolder.path).
            Your current Hotfolder limited (\(hotfolders.count)) is reached.
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

    func watch() -> AsyncStream<Change> {
        AsyncStream { continuation in
            Task {
                var knownFiles: [Hotfolder: [String: Date]] = [:]
                let oneSecoundInNanosecounds = 1_000_000_000.0

                while true {
                    try? await Task.sleep(nanoseconds: UInt64(config.watchInterval * oneSecoundInNanosecounds))

                    for hotfolder in hotfolders {
                        if knownFiles[hotfolder] == nil {
                            knownFiles[hotfolder] = [:]
                            let enumerator = fileManager.enumerator(atPath: hotfolder.path)
                            while let filePath = enumerator?.nextObject() as? String {
                                let fullPath = (hotfolder.path as NSString).appendingPathComponent(filePath)
                                if let attributes = try? fileManager.attributesOfItem(atPath: fullPath),
                                   let modificationDate = attributes[.modificationDate] as? Date
                                {
                                    knownFiles[hotfolder]![filePath] = modificationDate
                                }
                            }
                        }

                        let currentFiles = fileManager.enumerator(atPath: hotfolder.path)?.allObjects as? [String] ?? []

                        for filePath in currentFiles {
                            let fullPath = (hotfolder.path as NSString).appendingPathComponent(filePath)
                            if let attributes = try? fileManager.attributesOfItem(atPath: fullPath),
                               let modificationDate = attributes[.modificationDate] as? Date
                            {
                                if let knownDate = knownFiles[hotfolder]![filePath] {
                                    if modificationDate != knownDate {
                                        continuation.yield(.modified(Change.File(path: filePath, hotfolderPath: hotfolder.path)))
                                        knownFiles[hotfolder]![filePath] = modificationDate
                                    }
                                } else {
                                    continuation.yield(.created(Change.File(path: filePath, hotfolderPath: hotfolder.path)))
                                    knownFiles[hotfolder]![filePath] = modificationDate
                                }
                            }
                        }

                        for (filePath, _) in knownFiles[hotfolder]! {
                            if !currentFiles.contains(filePath) {
                                continuation.yield(.deleted(Change.File(path: filePath, hotfolderPath: hotfolder.path)))
                                knownFiles[hotfolder]!.removeValue(forKey: filePath)
                            }
                        }
                    }
                }
            }
        }
    }
}
