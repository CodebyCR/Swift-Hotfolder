import Foundation

struct Hotfolder: Hashable {
    let id = UUID()
    let path: String
    var name: String? {
        return URL(string: path)?.lastPathComponent
    }
}
