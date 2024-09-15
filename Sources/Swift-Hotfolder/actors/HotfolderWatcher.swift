//
//  HotfolderWatcher.swift
//  Hotfolder
//
//  Created by Christoph Rohde on 10.08.24.
//

import Combine
import Foundation
import os.log

@globalActor
public final actor HotfolderWatcher: GlobalActor {
    private let fileManager = FileManager.default
    private let config = WatcherConfig.default
    private let uptime: Date

    private(set) var hotfolders: Set<Hotfolder> = []
    private(set) var knownFiles: [Hotfolder: [String: Date]] = [:]
    private var runLoopTask: Task<Void, Never>?

    private(set) var isRunning: Bool

    public var count: Int {
        hotfolders.count
    }

    public static let shared = HotfolderWatcher()

    private init() {
        isRunning = false
        uptime = Date.now
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "hotfolder_logger",
        category: String(describing: HotfolderWatcher.self)
    )

    @discardableResult
    public final func stop() -> Bool {
        guard isRunning else {
            Self.logger.warning("""
            \(#file) -> \(#function) \(#line):\(#column)
            No task is running.
            """)
            return false
        }

        runLoopTask?.cancel()
        isRunning = false
        Self.logger.info("Background task stopped.")
        return true
    }

    @discardableResult
    public final func startWatching() async throws -> Bool {
        guard !hotfolders.isEmpty else {
            Self.logger.warning("""
            \(#file) -> \(#function) \(#line):\(#column)
            There are no hotfolders to observe.
            """)
            return false
        }

        guard !isRunning else {
            Self.logger.warning("""
            \(#file) -> \(#function) \(#line):\(#column)
            Task is already running.
            """)
            return true
        }

        isRunning = true
        runLoopTask = Task {
            do {
                try await runBackgroundTask()
            } catch {
                print(error.localizedDescription)
            }
        }

        Self.logger.info("Background task started.")
        return isRunning
    }

    private func runBackgroundTask() async throws {
        var knownFiles = self.knownFiles

        while !Task.isCancelled {
            try await Task.sleep(nanoseconds: UInt64(config.watchInterval * 1_000_000_000.0))
//            Self.logger.log("\(#file) -> \(#function) Looking for changes...")

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

    @discardableResult
    public final func add(_ hotfolder: Hotfolder) -> Result<Bool, Error> {
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

    @discardableResult
    public final func remove(_ hotfolder: Hotfolder) -> Bool {
        guard let droppedHotfolder = hotfolders.remove(hotfolder) else {
            Self.logger.warning("""
            \(#file) -> \(#function) \(#line):\(#column)
            The given Hotfolder is not contained.
            """)
            return false
        }

        knownFiles.removeValue(forKey: droppedHotfolder)
        return true
    }

    private final func checkForReleasableFiles(in knownFiles: inout [Hotfolder: [String: Date]]) async {
        for hotfolder in hotfolders where !knownFiles.keys.contains(hotfolder) {
            knownFiles.removeValue(forKey: hotfolder)
        }
    }

    private final func initializeKnownFiles(for hotfolder: Hotfolder) async throws -> [String: Date] {
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

    private final func getCurrentFiles(for hotfolder: Hotfolder) throws -> [String] {
        return fileManager.enumerator(atPath: hotfolder.path.path)?.allObjects as? [String] ?? []
    }

    private final func checkForChanges(hotfolder: Hotfolder, currentFiles: [String], knownFiles: inout [String: Date]) async throws {
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

    private final func checkForDeletions(hotfolder: Hotfolder, currentFiles: [String], knownFiles: inout [String: Date]) async throws {
        for (filePath, _) in knownFiles {
            if !currentFiles.contains(filePath) {
                knownFiles.removeValue(forKey: filePath)
                await hotfolder.deleteSubject.send(URL(fileURLWithPath: (hotfolder.path.path as NSString).appendingPathComponent(filePath)))
            }
        }
    }
}
