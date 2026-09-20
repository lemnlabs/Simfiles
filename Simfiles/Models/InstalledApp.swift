//
//  InstalledApp.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import AppKit
import Foundation

/// Represents an application installed on an Apple simulator device.
nonisolated struct InstalledApp: Identifiable, Hashable, Sendable {
    var id: String { bundleId }

    /// The bundle identifier of the application (e.g., `com.example.MyApp`).
    let bundleId: String

    /// The display name extracted from `CFBundleDisplayName` or `CFBundleName`.
    let displayName: String

    /// The version string (e.g., "1.2.0 (42)").
    let version: String

    /// File URL to the `.app` bundle directory inside `Containers/Bundle/Application`, if found.
    let bundleURL: URL?

    /// File URL to the root sandbox data container directory inside `Containers/Data/Application`.
    let dataURL: URL

    /// `true` if this is a built-in Apple system application (`com.apple.*`).
    let isSystemApp: Bool

    /// Raw PNG data for the application's primary icon, if extracted from the bundle.
    let iconData: Data?

    /// File URL to the sandbox `Documents` directory.
    var documentsURL: URL {
        dataURL.appending(
            component: "Documents",
            directoryHint: .isDirectory
        )
    }

    /// File URL to the sandbox `Library` directory.
    var libraryURL: URL {
        dataURL.appending(
            component: "Library",
            directoryHint: .isDirectory
        )
    }

    /// File URL to the sandbox `Library/Caches` directory.
    var cachesURL: URL {
        libraryURL.appending(
            component: "Caches",
            directoryHint: .isDirectory
        )
    }

    /// File URL to the sandbox `Library/Application Support` directory.
    var applicationSupportURL: URL {
        libraryURL.appending(
            component: "Application Support",
            directoryHint: .isDirectory
        )
    }

    /// File URL to the sandbox temporary directory (`tmp`).
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
