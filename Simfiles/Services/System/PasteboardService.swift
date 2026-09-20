//
//  PasteboardService.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import AppKit
import Foundation

/// Abstraction for writing text content into the macOS system pasteboard.
protocol PasteboardServiceProtocol: Sendable {
    /// Copies a single string to the general pasteboard.
    ///
    /// - Parameter string: The text string to copy.
    func copyString(_ string: String)

    /// Copies multiple strings joined by newlines to the general pasteboard.
    ///
    /// - Parameter strings: An array of strings to copy.
    func copyStrings(_ strings: [String])
}

/// Provides system pasteboard access using `NSPasteboard.general`.
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
