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

    func showAlert(title: String, message: String) {
        activeAlert = AlertItem(title: title, message: message)
    }

    func showError(_ error: Error, title: String = "오류 발생") {
        activeAlert = .error(error, title: title)
    }

    func handleIncomingExternalFiles(_ urls: [URL]) {
        guard let app = selectedApp else {
            showAlert(
                title: "전송 대상 앱 없음",
                message: "파일을 넣을 대상 시뮬레이터와 앱을 먼저 선택해 주세요."
            )
            return
        }

        do {
            let imported = try fileService.importFiles(from: urls, to: app.documentsURL)
            showAlert(
                title: "파일 추가 완료",
                message: "\(imported.count)개 파일이 '\(app.displayName)'의 Documents 폴더로 복사되었습니다."
            )
        } catch {
            showError(error, title: "파일 추가 실패")
        }
    }

    func selectDefaultDeviceIfNeeded(devices: [SimulatorDevice]) {
        guard selectedDevice == nil else {
            return
        }

        selectedDevice = devices.first(where: { $0.state.isBooted }) ?? devices.first
    }
}
