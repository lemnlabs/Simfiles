//
//  WorkspaceService.swift
//  SimulatorFileManager
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import AppKit
import Foundation

@MainActor
protocol WorkspaceServiceProtocol: Sendable {
    func revealInFinder(urls: [URL])
    func revealInFinder(url: URL)
    func openItem(url: URL)
}

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
