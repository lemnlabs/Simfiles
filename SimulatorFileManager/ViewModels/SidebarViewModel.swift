import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class SidebarViewModel {
    var searchText: String = ""
    var showOnlyBooted: Bool = false

    let simulatorManager: SimulatorManager
    private let workspaceService: WorkspaceServiceProtocol
    private let pasteboardService: PasteboardServiceProtocol

    init(
        simulatorManager: SimulatorManager,
        workspaceService: WorkspaceServiceProtocol = WorkspaceService(),
        pasteboardService: PasteboardServiceProtocol = PasteboardService()
    ) {
        self.simulatorManager = simulatorManager
        self.workspaceService = workspaceService
        self.pasteboardService = pasteboardService
    }

    var devices: [SimulatorDevice] {
        simulatorManager.devices
    }

    var isLoading: Bool {
        simulatorManager.isLoading
    }

    var runnerAppName: String {
        simulatorManager.runnerAppName
    }

    var filteredDevices: [SimulatorDevice] {
        devices.filter { device in
            let matchesSearch =
                searchText.isEmpty
                || device.name.localizedCaseInsensitiveContains(searchText)
                || device.runtime.localizedCaseInsensitiveContains(searchText)

            let matchesBooted = !showOnlyBooted || device.state.isBooted
            return matchesSearch && matchesBooted
        }
    }

    var groupedDevices: [String: [SimulatorDevice]] {
        Dictionary(grouping: filteredDevices, by: { $0.runtime })
    }

    var sortedRuntimes: [String] {
        groupedDevices.keys.sorted(by: >)
    }

    func refreshDevices() async {
        await simulatorManager.fetchDevices()
    }

    func bootDevice(_ device: SimulatorDevice) async {
        await simulatorManager.bootDevice(device)
    }

    func shutdownDevice(_ device: SimulatorDevice) async {
        await simulatorManager.shutdownDevice(device)
    }

    func openSimulatorApp(for device: SimulatorDevice) {
        simulatorManager.openSimulatorApp(for: device)
    }

    func revealInFinder(device: SimulatorDevice) {
        workspaceService.revealInFinder(url: device.dataURL)
    }

    func revealMediaFolder(for device: SimulatorDevice) {
        workspaceService.revealInFinder(url: device.mediaURL)
    }

    func addMedia(for device: SimulatorDevice) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image, .movie, .video]
        panel.prompt = String(localized: .simulatorActionAddMedia)

        if panel.runModal() == .OK {
            let urls = panel.urls
            Task {
                try? await simulatorManager.addMedia(udid: device.udid, mediaURLs: urls)
            }
        }
    }

    func copyUDID(for device: SimulatorDevice) {
        pasteboardService.copyString(device.udid)
    }
}
