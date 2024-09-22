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
    private let fileManager: FileManager
    private(set) var watcherConfig: WatcherConfig
    private var runTime: Date?

    private(set) var hotfolders: Set<Hotfolder>
    private(set) var knownFiles: [Hotfolder: [URL: Date]]
    private var runLoopTask: Task<Void, Error>?

    private(set) var isRunning: Bool {
        didSet(watcherStarted) {
            runTime = watcherStarted ? Date.now : nil
            isRunning = watcherStarted
        }
    }

    public var count: Int {
        hotfolders.count
    }

    public static let shared = HotfolderWatcher()

    private init() {
        fileManager = FileManager.default
        watcherConfig = WatcherConfig.default
        isRunning = false
        hotfolders = []
        knownFiles = [:]
    }

    public func setup(_ watcherConfig: WatcherConfig) throws {
        guard !isRunning else {
            throw HotfolderWatcherError.hotfolderWatcherCurrentlyRun("""
            HotfolderWatcher cannot be modified while it is running.
            """)
        }

        self.watcherConfig = watcherConfig
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
                throw error
            }
        }

        Self.logger.info("Background task started.")
        return isRunning
    }

    @discardableResult
    public final func add(_ hotfolder: Hotfolder) -> Result<Bool, Error> {
        guard hotfolders.count < watcherConfig.maxHotfolderCount else {
            return .failure(HotfolderWatcherError.maxHotfolderCountReached("Max hotfolder count reached"))
        }

        if watcherConfig.createNonExistingFolders, !fileManager.fileExists(atPath: hotfolder.path.path) {
            do {
                try fileManager.createDirectory(at: hotfolder.path, withIntermediateDirectories: true, attributes: nil)
                #if DEBUG
                    Self.logger.info("Hotfolder created")
                #endif
            } catch {
                return .failure(HotfolderWatcherError.hotfolderCantBeCreated("Hotfolder can't be created: \(error)"))
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

    private func runBackgroundTask() async throws {
        var knownFiles = self.knownFiles
        let watchInterval = UInt64(watcherConfig.watchInterval * 1_000_000_000.0)

        while !Task.isCancelled {
            try await Task.sleep(nanoseconds: watchInterval)

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

    private final func initializeKnownFiles(for hotfolder: Hotfolder) async throws -> [URL: Date] {
        var knownFiles: [URL: Date] = [:]
        let enumerator = fileManager.enumerator(at: hotfolder.path, includingPropertiesForKeys: nil, options: watcherConfig.enumerationOptions)

        while let filePath = enumerator?.nextObject() as? URL {
            if let attributes = try? fileManager.attributesOfItem(atPath: filePath.path),
               let modificationDate = attributes[.modificationDate] as? Date
            {
                knownFiles[filePath] = modificationDate
            }
        }

        return knownFiles
    }

    private final func getCurrentFiles(for hotfolder: Hotfolder) throws -> [URL] {
        let dircetoryEnumerator = fileManager.enumerator(at: hotfolder.path, includingPropertiesForKeys: nil, options: watcherConfig.enumerationOptions)
        return dircetoryEnumerator?.allObjects as? [URL] ?? []
    }

    private final func checkForChanges(hotfolder: Hotfolder, currentFiles: [URL], knownFiles: inout [URL: Date]) async throws {
        for filePath in currentFiles {
            if let attributes = try? fileManager.attributesOfItem(atPath: filePath.path),
               let modificationDate = attributes[.modificationDate] as? Date
            {
                if let knownDate = knownFiles[filePath] {
                    if modificationDate != knownDate {
                        knownFiles[filePath] = modificationDate
                        hotfolder.modifySubject.send(filePath)
                    }
                } else {
                    knownFiles[filePath] = modificationDate
                    hotfolder.createSubject.send(filePath)
                }
            }
        }
    }

    private final func checkForDeletions(hotfolder: Hotfolder, currentFiles: [URL], knownFiles: inout [URL: Date]) async throws {
        for filePath in knownFiles.keys {
            if !currentFiles.contains(filePath) {
                knownFiles.removeValue(forKey: filePath)
                hotfolder.deleteSubject.send(filePath)
            }
        }
    }
}
