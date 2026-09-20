//
//  AlertItem.swift
//  SimulatorFileManager
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import Foundation

struct AlertItem: Identifiable, Equatable {
    let id: UUID
    let title: LocalizedStringResource
    let message: String

    init(id: UUID = UUID(), title: LocalizedStringResource, message: String) {
        self.id = id
        self.title = title
        self.message = message
    }
}

extension AlertItem {
    static func error(_ error: Error, title: LocalizedStringResource = .commonErrorOccurred)
        -> AlertItem
    {
        AlertItem(title: title, message: error.localizedDescription)
    }
}
