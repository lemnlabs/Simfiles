//
//  SandboxDirectory.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import Foundation

/// Standard application container sandbox directories accessible for browsing.
enum SandboxDirectory: String, CaseIterable, Identifiable, Sendable {
    /// The user-visible persistent document storage (`Documents`).
    case documents = "Documents"

    /// The app-private support and configuration directory (`Library`).
    case library = "Library"

    /// Temporary files that may be purged by the system (`tmp`).
    case tmp = "tmp"

    /// The root data container folder encompassing all sandbox subdirectories.
    case root = "Root"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .documents: return "doc.on.doc"
        case .library: return "books.vertical"
        case .tmp: return "clock.arrow.circlepath"
        case .root: return "folder"
        }
    }
}
