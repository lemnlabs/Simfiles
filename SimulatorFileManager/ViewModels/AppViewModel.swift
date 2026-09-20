import Foundation
import Observation

@Observable
@MainActor
final class AppViewModel {
    var selectedDevice: SimulatorDevice?
    var selectedApp: InstalledApp?

    var activeAlert: AlertItem?

    private let fileService: FileManagerServiceProtocol

    init(fileService: FileManagerServiceProtocol = FileManagerService()) {
        self.fileService = fileService
    }

    var navigationTitleText: String {
        if let app = selectedApp, let device = selectedDevice {
            return "\(device.name) — \(app.displayName)"
        } else if let device = selectedDevice {
            return device.name
        }
        return "Simulator File Manager"
    }

    func showAlert(title: LocalizedStringResource, message: String) {
        activeAlert = AlertItem(title: title, message: message)
    }

    func showError(_ error: Error, title: LocalizedStringResource = .commonErrorOccurred) {
        activeAlert = .error(error, title: title)
    }

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

    func selectDefaultDeviceIfNeeded(devices: [SimulatorDevice]) {
        guard selectedDevice == nil else {
            return
        }

        selectedDevice = devices.first(where: { $0.state.isBooted }) ?? devices.first
    }
}
