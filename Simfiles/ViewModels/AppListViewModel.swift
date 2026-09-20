//
//  AppListViewModel.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

/// Filter scope for categorizing installed applications in the app list.
enum AppFilterScope: CaseIterable, Identifiable {
    /// Show only user-installed third-party applications.
    case userOnly
    /// Show all applications including Apple built-in system apps.
    case all

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .userOnly:
            return .appListFilterUserApps
        case .all:
            return .appListFilterAllApps
        }
    }
}

/// Manages the discovery, filtering, and selection of applications installed on a chosen simulator device.
@Observable
@MainActor
final class AppListViewModel {
    /// Applications discovered on the current device.
    var installedApps: [InstalledApp] = []

    /// `true` while the app scanner is scanning container directories.
    var isLoading: Bool = false

    /// Search query string matching app display name or bundle identifier.
    var searchText: String = ""

    /// Active filter category (user-installed apps vs. all apps).
    var filterScope: AppFilterScope = .userOnly

    var hideSystemApps: Bool {
        get { filterScope == .userOnly }
        set { filterScope = newValue ? .userOnly : .all }
    }

    /// The simulator device currently being inspected.
    var currentDevice: SimulatorDevice?

    private let appScanner: AppScanner
    private let simulatorManager: SimulatorManager?
    private let workspaceService: WorkspaceServiceProtocol
    private let pasteboardService: PasteboardServiceProtocol

    /// Initializes the app list view model with its required dependencies.
    ///
    /// - Parameters:
    ///   - appScanner: Service scanner for reading app container metadata.
    ///   - simulatorManager: Simulator manager for checking process execution status.
    ///   - workspaceService: Service for Finder file reveal actions.
    ///   - pasteboardService: Service for copying bundle IDs and file paths.
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

    /// Applications matching the current search text and filter scope.
    var filteredApps: [InstalledApp] {
        installedApps.filter { app in
            let matchesSearch =
                searchText.isEmpty || app.displayName.localizedCaseInsensitiveContains(searchText)
                || app.bundleId.localizedCaseInsensitiveContains(searchText)

            let matchesSystem = (filterScope == .all) || !app.isSystemApp
            return matchesSearch && matchesSystem
        }
    }

    /// Checks whether an application is currently executing on the current simulator.
    ///
    /// - Parameter bundleId: The bundle identifier of the application.
    /// - Returns: `true` if the app process is currently active.
    func isAppRunning(bundleId: String) -> Bool {
        guard let currentDevice else { return false }
        return simulatorManager?.isAppRunning(device: currentDevice, bundleId: bundleId) ?? false
    }

    /// Loads installed applications for the specified simulator device asynchronously.
    ///
    /// - Parameters:
    ///   - device: Target simulator device to scan. Pass `nil` to clear the list.
    ///   - onSelectionResolved: Callback invoked with the recommended initial app selection (user app preferred).
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

    /// Reveals the application's sandbox data folder in macOS Finder.
    ///
    /// - Parameter app: The installed application.
    func revealDataFolderInFinder(for app: InstalledApp) {
        workspaceService.revealInFinder(url: app.dataURL)
    }

    /// Reveals the application's `.app` bundle directory in macOS Finder.
    ///
    /// - Parameter app: The installed application.
    func revealBundleInFinder(for app: InstalledApp) {
        if let bundleURL = app.bundleURL {
            workspaceService.revealInFinder(url: bundleURL)
        }
    }

    /// Reveals the simulator's shared media directory in macOS Finder.
    func revealMediaFolderInFinder() {
        if let currentDevice {
            workspaceService.revealInFinder(url: currentDevice.mediaURL)
        }
    }

    /// Opens an open file panel to select media files and imports them to the current device.
    func addMediaToCurrentDevice() {
        guard let currentDevice, currentDevice.state.isBooted else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image, .movie, .video]
        panel.prompt = String(localized: .simulatorActionAddMedia)

        if panel.runModal() == .OK {
            let urls = panel.urls
            Task {
                try? await simulatorManager?.addMedia(udid: currentDevice.udid, mediaURLs: urls)
            }
        }
    }

    /// Copies the application's bundle identifier to the system pasteboard.
    ///
    /// - Parameter app: The installed application.
    func copyBundleId(for app: InstalledApp) {
        pasteboardService.copyString(app.bundleId)
    }

    /// Copies the application's sandbox data folder path to the system pasteboard.
    ///
    /// - Parameter app: The installed application.
    func copyDataFolderPath(for app: InstalledApp) {
        pasteboardService.copyString(app.dataURL.path)
    }
}
