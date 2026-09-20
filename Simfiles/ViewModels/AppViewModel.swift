//
//  AppViewModel.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import Foundation
import Observation

/// Coordinates top-level application navigation, device/app selection, and global alerts.
@Observable
@MainActor
final class AppViewModel {
    /// The simulator device currently selected in the sidebar.
    var selectedDevice: SimulatorDevice?

    /// The application currently selected in the app list.
    var selectedApp: InstalledApp?

    /// Active alert modal or banner state.
    var activeAlert: AlertItem?

    private let fileService: FileManagerServiceProtocol

    /// Initializes the root app view model.
    ///
    /// - Parameter fileService: File service implementation for external file imports.
    init(fileService: FileManagerServiceProtocol = FileManagerService()) {
        self.fileService = fileService
    }

    /// Computed window title based on current selection state.
    var navigationTitleText: String {
        if let app = selectedApp, let device = selectedDevice {
            return "\(device.name) — \(app.displayName)"
        } else if let device = selectedDevice {
            return device.name
        }
        return "Simfiles"
    }

    /// Displays an informational alert dialog.
    ///
    /// - Parameters:
    ///   - title: Localized resource for the alert title.
    ///   - message: Detailed descriptive message body.
    func showAlert(title: LocalizedStringResource, message: String) {
        activeAlert = AlertItem(title: title, message: message)
    }

    /// Displays an error alert dialog.
    ///
    /// - Parameters:
    ///   - error: The error to present.
    ///   - title: Localized resource for the alert title. Defaults to `.commonErrorOccurred`.
    func showError(_ error: Error, title: LocalizedStringResource = .commonErrorOccurred) {
        activeAlert = .error(error, title: title)
    }

    /// Handles file URLs dragged or opened into the application window from external sources.
    ///
    /// Files are imported directly into the active application's `Documents` sandbox directory.
    /// - Parameter urls: The incoming external file URLs.
    func handleIncomingExternalFiles(_ urls: [URL]) {
        guard let app = selectedApp else {
            showAlert(
                title: .appImportNoTargetTitle,
                message: String(localized: .appImportNoTargetMessage)
            )
            return
        }

        do {
            let imported = try fileService.importFiles(from: urls, to: app.documentsURL)
            showAlert(
                title: .appImportSuccessTitle,
                message: String(
                    localized: .appImportSuccessMessage(imported.count, app.displayName))
            )
        } catch {
            showError(error, title: .appImportFailureTitle)
        }
    }

    /// Automatically selects an active or initial simulator device if no device is selected yet.
    ///
    /// Prioritizes currently booted devices over shutdown devices.
    /// - Parameter devices: The pool of discovered simulator devices.
    func selectDefaultDeviceIfNeeded(devices: [SimulatorDevice]) {
        guard selectedDevice == nil else {
            return
        }

        selectedDevice = devices.first(where: { $0.state.isBooted }) ?? devices.first
    }
}
