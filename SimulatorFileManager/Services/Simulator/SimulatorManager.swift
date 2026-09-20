//
//  SimulatorManager.swift
//  SimulatorFileManager
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import Foundation
import Observation

@Observable
@MainActor
final class SimulatorManager {
    var devices: [SimulatorDevice] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var runningAppBundleIds: Set<String> = []

    private let simctlClient: SimctlClientProtocol

    init(simctlClient: SimctlClientProtocol = SimctlClient()) {
        self.simctlClient = simctlClient
    }

    var runnerAppName: String {
        simctlClient.runnerAppName
    }

    func fetchDevices() async {
        isLoading = true
        errorMessage = nil

        do {
            self.devices = try await simctlClient.listDevices()
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    func bootDevice(_ device: SimulatorDevice) async {
        do {
            try await simctlClient.bootDevice(udid: device.udid)
            await fetchDevices()
        } catch {
            self.errorMessage = String(
                localized: .simulatorErrorBootFailed(error.localizedDescription)
            )
        }
    }

    func shutdownDevice(_ device: SimulatorDevice) async {
        do {
            try await simctlClient.shutdownDevice(udid: device.udid)
            await fetchDevices()
        } catch {
            self.errorMessage = String(
                localized: .simulatorErrorShutdownFailed(error.localizedDescription)
            )
        }
    }

    @discardableResult
    func fetchRunningAppBundleIds(for device: SimulatorDevice) async -> Set<String> {
        guard device.state.isBooted else {
            self.runningAppBundleIds = []
            return []
        }

        do {
            let running = try await simctlClient.fetchRunningAppBundleIds(udid: device.udid)
            self.runningAppBundleIds = running
            return running
        } catch {
            self.runningAppBundleIds = []
            return []
        }
    }

    func isAppRunning(device: SimulatorDevice, bundleId: String) -> Bool {
        guard device.state.isBooted else { return false }
        return runningAppBundleIds.contains(bundleId)
    }

    func launchApp(device: SimulatorDevice, bundleId: String) async {
        do {
            try await simctlClient.launchApp(udid: device.udid, bundleId: bundleId)
            _ = await fetchRunningAppBundleIds(for: device)
        } catch {
            self.errorMessage = String(
                localized: .simulatorErrorLaunchFailed(error.localizedDescription)
            )
        }
    }

    func terminateApp(device: SimulatorDevice, bundleId: String) async {
        do {
            try await simctlClient.terminateApp(udid: device.udid, bundleId: bundleId)
            _ = await fetchRunningAppBundleIds(for: device)
        } catch {
            self.errorMessage = String(
                localized: .simulatorErrorTerminateFailed(error.localizedDescription)
            )
        }
    }

    func openSimulatorApp(for device: SimulatorDevice? = nil) {
        simctlClient.openSimulatorApp(for: device?.udid)
    }

    func addMedia(udid: String, mediaURLs: [URL]) async throws {
        try await simctlClient.addMedia(udid: udid, mediaURLs: mediaURLs)
    }
}
