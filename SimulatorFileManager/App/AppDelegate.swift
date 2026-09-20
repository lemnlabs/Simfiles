import AppKit
import Foundation

extension Notification.Name {
    static let didReceiveExternalFiles = Notification.Name("didReceiveExternalFiles")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty else { return }

        NotificationCenter.default.post(
            name: .didReceiveExternalFiles,
            object: nil,
            userInfo: ["urls": urls]
        )
    }
}
