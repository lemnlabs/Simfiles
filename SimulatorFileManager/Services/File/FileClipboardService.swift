import Foundation
import Observation

enum ClipboardOperation: Sendable {
    case copy
    case cut
}

@Observable
@MainActor
final class FileClipboardService {
    var urls: [URL] = []
    var operation: ClipboardOperation = .copy

    var isEmpty: Bool {
        urls.isEmpty
    }

    var count: Int {
        urls.count
    }

    var isCut: Bool {
        operation == .cut
    }

    func copy(urls: [URL]) {
        self.urls = urls
        self.operation = .copy
    }

    func cut(urls: [URL]) {
        self.urls = urls
        self.operation = .cut
    }

    func clear() {
        self.urls = []
        self.operation = .copy
    }
}
