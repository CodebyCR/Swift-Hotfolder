//
//  HotfolderMonitor.swift
//  Hotfolder
//
//  Created by Christoph Rohde on 10.08.24.
//

import Foundation

public enum HotfolderMonitor {
    public static func main() async {
        print("Start main async")

        let watcher = HotfolderWatcher()

        let hotfolder1 = Hotfolder(path: "/Users/christoph_rohde/Test_Hotfolder1")
        let hotfolder2 = Hotfolder(path: "/Users/christoph_rohde/Test_Hotfolder2")

        // Add initial hotfolders
        await watcher.add(hotfolder: hotfolder1)
        await watcher.add(hotfolder: hotfolder2)

        // Start watching
        do {
            try await watcher.watch { change in
                switch change {
                case .created(let file):
                    print("Created:  '\(file.path)' in '\(file.hotfolderPath)'")
                case .modified(let file):
                    print("Modified: '\(file.path)' in '\(file.hotfolderPath)'")
                case .deleted(let file):
                    print("Deleted:  '\(file.path)' in '\(file.hotfolderPath)'")
                }
            }
        } catch {
            print("Error to: \(error)")
        }

        // Simulate adding a new hotfolder after a delay
        Task {
            let fiveSeconds: UInt64 = 5_000_000_000
            try await Task.sleep(nanoseconds: consume fiveSeconds)
            let hotfolder3 = Hotfolder(path: "/Users/christoph_rohde/Test_Hotfolder3")
            await watcher.add(hotfolder: hotfolder3)
            print("Added new hotfolder")
        }
    }
}
