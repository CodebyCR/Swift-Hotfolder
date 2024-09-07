import Combine
import Foundation

public struct Hotfolder: Equatable, Hashable {
    // Properties
    let path: URL

    var name: String? {
        return path.lastPathComponent
    }

    public let createSubject = PassthroughSubject<URL, Never>()
    public let modifySubject = PassthroughSubject<URL, Never>()
    public let deleteSubject = PassthroughSubject<URL, Never>()

    public init(at path: URL) {
        self.path = path
    }

    public init?(atPath path: String) {
        guard let checkedPath = URL(string: path) else {
            // Undecodable URL
            return nil
        }

        self.path = checkedPath
    }

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
    public static func == (lhs: Hotfolder, rhs: Hotfolder) -> Bool {
        lhs.path == rhs.path
    }

    /// Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
}
