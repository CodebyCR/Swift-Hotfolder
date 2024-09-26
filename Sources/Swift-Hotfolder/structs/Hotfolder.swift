import Combine
import Foundation

public struct Hotfolder: Equatable, Hashable {
    // Properties
    @available(macOS, introduced: 14)
    public let path: URL

    @available(macOS, introduced: 14)
    public var name: String? {
        return path.lastPathComponent
    }

    @available(macOS, introduced: 14)
    public let createSubject = PassthroughSubject<URL, Never>()

    @available(macOS, introduced: 14)
    public let modifySubject = PassthroughSubject<URL, Never>()

    @available(macOS, introduced: 14)
    public let deleteSubject = PassthroughSubject<URL, Never>()

    @available(macOS, introduced: 14)
    public init(at path: URL) {
        self.path = path
    }

    @available(macOS, introduced: 14)
    public init?(atPath path: String) {
        guard let checkedPath = URL(string: path) else {
            // Undecodable URL
            return nil
        }

        self.path = checkedPath
    }

    
    /// Published a Change to the specific Subject
    /// - Parameter change: The Change which descrips the kind of change and hold the affected URL.
    @available(macOS, introduced: 14)
    public func publish(change: Change) {
        switch change {
        case .created(let url):
            createSubject.send(url)
        case .modified(let url):
            modifySubject.send(url)
        case .deleted(let url):
            deleteSubject.send(url)
        }
    }

    /// Equatable conformance
    @available(macOS, introduced: 1.0.0)
    public static func == (lhs: Hotfolder, rhs: Hotfolder) -> Bool {
        lhs.path == rhs.path
    }

    /// Hashable conformance
    @available(macOS, introduced: 14)
    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
}
