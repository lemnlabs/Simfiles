//
//  FileClipboardService.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import Foundation
import Observation

/// The type of file clipboard transfer action.
enum ClipboardOperation: Sendable {
    /// Items should be copied to the destination.
    case copy
    /// Items should be relocated to the destination and removed from the original directory.
    case cut
}

/// In-memory clipboard store managing files targeted for copy or cut actions.
@Observable
@MainActor
final class FileClipboardService {
    /// The file URLs currently held in the internal clipboard.
    var urls: [URL] = []

    /// The pending clipboard action (copy or cut).
    var operation: ClipboardOperation = .copy

    /// `true` if the clipboard contains no files.
    var isEmpty: Bool {
        urls.isEmpty
    }

    /// The number of files currently held in the clipboard.
    var count: Int {
        urls.count
    }

    /// `true` if the active operation is a cut action.
    var isCut: Bool {
        operation == .cut
    }

    /// Stores the provided URLs for a copy operation.
    ///
    /// - Parameter urls: The target file URLs to copy.
    func copy(urls: [URL]) {
        self.urls = urls
        self.operation = .copy
    }

    /// Stores the provided URLs for a cut (move) operation.
    ///
    /// - Parameter urls: The target file URLs to cut.
    func cut(urls: [URL]) {
        self.urls = urls
        self.operation = .cut
    }

    /// Clears the clipboard contents and resets operation to `.copy`.
    func clear() {
        self.urls = []
        self.operation = .copy
    }
}
