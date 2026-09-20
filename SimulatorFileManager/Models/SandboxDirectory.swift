//
//  SandboxDirectory.swift
//  SimulatorFileManager
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import Foundation

enum SandboxDirectory: String, CaseIterable, Identifiable, Sendable {
    case documents = "Documents"
    case library = "Library"
    case tmp = "tmp"
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
