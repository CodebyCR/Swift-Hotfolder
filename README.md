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
> This will change when v.1.0.0 is released.

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

        guard let hotfolderURL = URL(string: "/Users/USER_NAME/Desktop/My_firts_Hotfolder") else {
            print("HotfolderURL can't be created")
            return
        }

        let hotfolder = Hotfolder(at: hotfolderURL)

        let modifyCancellable = hotfolder.modifySubject.sink { modifiedUrl in
            print("Modified: \(modifiedUrl.path(percentEncoded: false))")
        }

        let deleteCancellable = hotfolder.deleteSubject.sink { deletedUrl in
            print("Deleted: \(deletedUrl.path(percentEncoded: false))")
        }

        let createCancellable = hotfolder.createSubject.sink { createdUrl in
            print("Created: \(createdUrl.path(percentEncoded: false))")
        }

        await HotfolderWatcher.shared.add(hotfolder)

        // Start watching
        do {
            try await HotfolderWatcher.shared.startWatching()
        } catch {
            print("Error in 'HotfolderWatcher.startWatching': \(error)")
        }
    }
}
```
