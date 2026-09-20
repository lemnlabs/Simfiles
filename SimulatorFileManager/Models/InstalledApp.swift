//
//  InstalledApp.swift
//  SimulatorFileManager
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import AppKit
import Foundation

nonisolated struct InstalledApp: Identifiable, Hashable, Sendable {
    var id: String { bundleId }
    let bundleId: String
    let displayName: String
    let version: String
    let bundleURL: URL?
    let dataURL: URL
    let isSystemApp: Bool
    let iconData: Data?

    var documentsURL: URL {
        dataURL.appending(
            component: "Documents",
            directoryHint: .isDirectory
        )
    }

    var libraryURL: URL {
        dataURL.appending(
            component: "Library",
            directoryHint: .isDirectory
        )
    }

    var cachesURL: URL {
        libraryURL.appending(
            component: "Caches",
            directoryHint: .isDirectory
        )
    }

    var applicationSupportURL: URL {
        libraryURL.appending(
            component: "Application Support",
            directoryHint: .isDirectory
        )
    }

    var tmpURL: URL {
        dataURL.appending(
            component: "tmp",
            directoryHint: .isDirectory
        )
    }

    init(
        bundleId: String,
        displayName: String,
        version: String,
        bundleURL: URL?,
        dataURL: URL,
        isSystemApp: Bool,
        iconData: Data? = nil
    ) {
        self.bundleId = bundleId
        self.displayName = displayName
        self.version = version
        self.bundleURL = bundleURL
        self.dataURL = dataURL
        self.isSystemApp = isSystemApp
        self.iconData = iconData
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleId)
        hasher.combine(dataURL)
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.bundleId == rhs.bundleId && lhs.dataURL == rhs.dataURL
    }
}
