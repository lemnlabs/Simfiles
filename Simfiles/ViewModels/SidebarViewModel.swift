//
//  SidebarViewModel.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

/// Manages simulator device filtering, runtime grouping, and device-level actions in the sidebar.
@Observable
@MainActor
final class SidebarViewModel {
    /// Search query string to filter simulators by name or OS runtime.
    var searchText: String = ""

    /// When true, only simulators in the `.booted` state are shown.
    var showOnlyBooted: Bool = false

    let simulatorManager: SimulatorManager
    private let workspaceService: WorkspaceServiceProtocol
    private let pasteboardService: PasteboardServiceProtocol

    /// Initializes the sidebar view model with required dependencies.
    ///
    /// - Parameters:
    ///   - simulatorManager: The central simulator manager coordinating device states.
    ///   - workspaceService: Workspace service for opening Finder and native apps.
    ///   - pasteboardService: Pasteboard service for copying device UDIDs.
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

    /// The list of devices filtered by search query and boot filter toggle.
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

    /// Devices grouped by their runtime string (e.g., "iOS 18.2").
    var groupedDevices: [String: [SimulatorDevice]] {
        Dictionary(grouping: filteredDevices, by: { $0.runtime })
    }

    /// Runtimes sorted in descending order for section headers.
    var sortedRuntimes: [String] {
        groupedDevices.keys.sorted(by: >)
    }

    /// Triggers an asynchronous reload of the simulator devices list.
    func refreshDevices() async {
        await simulatorManager.fetchDevices()
    }

    /// Boots the specified simulator device.
    ///
    /// - Parameter device: The target simulator.
    func bootDevice(_ device: SimulatorDevice) async {
        await simulatorManager.bootDevice(device)
    }

    /// Shuts down the specified simulator device.
    ///
    /// - Parameter device: The target simulator.
    func shutdownDevice(_ device: SimulatorDevice) async {
        await simulatorManager.shutdownDevice(device)
    }

    /// Opens the official Simulator.app or Device Hub app window.
    ///
    /// - Parameter device: The simulator device to focus.
    func openSimulatorApp(for device: SimulatorDevice) {
        simulatorManager.openSimulatorApp(for: device)
    }

    /// Reveals the simulator's root data folder in macOS Finder.
    ///
    /// - Parameter device: The target simulator device.
    func revealInFinder(device: SimulatorDevice) {
        workspaceService.revealInFinder(url: device.dataURL)
    }

    /// Reveals the simulator's shared media folder in macOS Finder.
    ///
    /// - Parameter device: The target simulator device.
    func revealMediaFolder(for device: SimulatorDevice) {
        workspaceService.revealInFinder(url: device.mediaURL)
    }

    /// Displays an open file panel to select photos/videos and imports them into the simulator.
    ///
    /// - Parameter device: The booted simulator device to receive the media.
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

    /// Copies the simulator's UDID to the macOS pasteboard.
    ///
    /// - Parameter device: The target simulator device.
    func copyUDID(for device: SimulatorDevice) {
        pasteboardService.copyString(device.udid)
    }
}
