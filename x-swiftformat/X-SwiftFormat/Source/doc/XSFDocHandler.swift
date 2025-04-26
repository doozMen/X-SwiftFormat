import Cocoa
import SwiftFormat

class XSFDocHandler: NSObject {

  static func handle(filenames: [String]) {
    for filename in filenames {
      let components = filename.split(separator: "/")
      if let last = components.last {
        let split = last.split(separator: ".")
        if split.count == 2 {
          let fileExtension = split[1].lowercased()
          if fileExtension == "swift-format" || fileExtension == "json" {
            readConfigurationFile(with: URL(fileURLWithPath: filename))
          }
        }
      }
    }
  }

  static func readConfigurationFile(with url: URL) {
    do {
      let configuration = try Configuration(contentsOf: url)
      Notifications.shared.postNotification(name: .readXSFFile, object: configuration)
    } catch {
      print("Error reading configuration file: \(error)")
    }
  }
}
