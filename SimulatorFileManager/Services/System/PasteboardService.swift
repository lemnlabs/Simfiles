import AppKit
import Foundation

protocol PasteboardServiceProtocol: Sendable {
    func copyString(_ string: String)
    func copyStrings(_ strings: [String])
}

nonisolated final class PasteboardService: PasteboardServiceProtocol, Sendable {
    init() {}

    func copyString(_ string: String) {
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
    }

    func copyStrings(_ strings: [String]) {
        copyString(strings.joined(separator: "\n"))
    }
}
