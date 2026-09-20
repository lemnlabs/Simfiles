//
//  WorkspaceService.swift
//  SimulatorFileManager
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import AppKit
import Foundation

/// Defines integration methods with macOS desktop workspace APIs (`NSWorkspace`).
@MainActor
protocol WorkspaceServiceProtocol: Sendable {
    /// Opens Finder and selects the specified file or folder URLs.
    ///
    /// - Parameter urls: The array of URLs to select in Finder.
    func revealInFinder(urls: [URL])

    /// Opens Finder and selects the specified file or folder URL.
    ///
    /// - Parameter url: The file or directory URL to select in Finder.
    func revealInFinder(url: URL)

    /// Opens the specified URL with the user's default macOS application.
    ///
    /// - Parameter url: The file or document URL to open.
    func openItem(url: URL)
}

/// Executes workspace actions via macOS `NSWorkspace.shared`.
@MainActor
final class WorkspaceService: WorkspaceServiceProtocol {
    init() {}

    func revealInFinder(urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func revealInFinder(url: URL) {
        revealInFinder(urls: [url])
    }

    func openItem(url: URL) {
        NSWorkspace.shared.open(url)
    }
}
