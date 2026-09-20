import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

enum AppFilterScope: String, CaseIterable, Identifiable {
    case userOnly = "사용자 앱"
    case all = "전체"
    var id: String { rawValue }
}

@Observable
@MainActor
final class AppListViewModel {
    var installedApps: [InstalledApp] = []
    var isLoading: Bool = false
    var searchText: String = ""
    var filterScope: AppFilterScope = .userOnly
    var hideSystemApps: Bool {
        get { filterScope == .userOnly }
        set { filterScope = newValue ? .userOnly : .all }
    }

    var currentDevice: SimulatorDevice?

    private let appScanner: AppScanner
    private let simulatorManager: SimulatorManager?
    private let workspaceService: WorkspaceServiceProtocol
    private let pasteboardService: PasteboardServiceProtocol

    init(
        appScanner: AppScanner = AppScanner(),
        simulatorManager: SimulatorManager? = nil,
        workspaceService: WorkspaceServiceProtocol = WorkspaceService(),
        pasteboardService: PasteboardServiceProtocol = PasteboardService()
    ) {
        self.appScanner = appScanner
        self.simulatorManager = simulatorManager
        self.workspaceService = workspaceService
        self.pasteboardService = pasteboardService
    }

    var filteredApps: [InstalledApp] {
        installedApps.filter { app in
            let matchesSearch =
                searchText.isEmpty || app.displayName.localizedCaseInsensitiveContains(searchText)
                || app.bundleId.localizedCaseInsensitiveContains(searchText)

            let matchesSystem = (filterScope == .all) || !app.isSystemApp
            return matchesSearch && matchesSystem
        }
    }

    func isAppRunning(bundleId: String) -> Bool {
        guard let currentDevice else { return false }
        return simulatorManager?.isAppRunning(device: currentDevice, bundleId: bundleId) ?? false
    }

    func loadApps(
        for device: SimulatorDevice?, onSelectionResolved: ((InstalledApp?) -> Void)? = nil
    ) {
        self.currentDevice = device
        guard let device else {
            installedApps = []
            onSelectionResolved?(nil)
            return
        }

        isLoading = true
        Task {
            async let appsTask = appScanner.scanInstalledApps(for: device)
            async let runningTask: Set<String>? = simulatorManager?.fetchRunningAppBundleIds(
                for: device)

            let apps = await appsTask
            _ = await runningTask

            self.installedApps = apps
            self.isLoading = false

            onSelectionResolved?(apps.first(where: { !$0.isSystemApp }) ?? apps.first)
        }
    }

    func revealDataFolderInFinder(for app: InstalledApp) {
        workspaceService.revealInFinder(url: app.dataURL)
    }

    func revealBundleInFinder(for app: InstalledApp) {
        if let bundleURL = app.bundleURL {
            workspaceService.revealInFinder(url: bundleURL)
        }
    }

    func revealMediaFolderInFinder() {
        if let currentDevice {
            workspaceService.revealInFinder(url: currentDevice.mediaURL)
        }
    }

    func addMediaToCurrentDevice() {
        guard let currentDevice, currentDevice.state.isBooted else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image, .movie, .video]
        panel.prompt = "사진/동영상 추가"

        if panel.runModal() == .OK {
            let urls = panel.urls
            Task {
                try? await simulatorManager?.addMedia(udid: currentDevice.udid, mediaURLs: urls)
            }
        }
    }

    func copyBundleId(for app: InstalledApp) {
        pasteboardService.copyString(app.bundleId)
    }

    func copyDataFolderPath(for app: InstalledApp) {
        pasteboardService.copyString(app.dataURL.path)
    }
}
