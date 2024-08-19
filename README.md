<h1 align="center">Swift Hotfolder</h1>

<div align="center">  
    <img height="28" height="28" src="https://img.shields.io/badge/mac%20os-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Logo" />
    <img height="28" height="28" src="https://img.shields.io/badge/Swift-FA7343?style=for-the-badge&logo=swift&logoColor=white" alt="Logo" />
    <img height="28" height="28" src="https://img.shields.io/github/license/CodebyCR/Swift-Hotfolder" alt="Logo" />
    <img height="28" height="28" src="https://img.shields.io/github/actions/workflow/status/CodebyCR/Swift-Hotfolder/swift.yml" alt="Logo" />
    <img height="28" height="28" src="https://img.shields.io/github/stars/CodebyCR/Swift-Hotfolder.svg" alt="Logo" />
    <h6>
      <em>Monitor your directories asyncronusly.</em>
    </h6>
</div>

<br/>

> [!IMPORTANT]
> This Swift package is currently in an early state and not ready to use.<br/>
> This will change if v.1.0.0 will published.

### \#ConstributersWelcome❤️

> [!NOTE]
> This package uses semantic versioning.


### Example Usage

```Swift
import Foundation
import Swift_Hotfolder

@main
struct HotfolderApp {

    static func main() async {
        print("Welcome to Swift Hotfolder🔥")
        let watcher = HotfolderWatcher()
        let hotfolder = Hotfolder(path: "/Users/USER_NAME/Desktop/My_firts_Hotfolder")

        await watcher.add(hotfolder: hotfolder)

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
            print("Error in 'HotfolderWatcher.watch()': \(error)")
        }
    }

}
```
