//
//  SimulatorManager.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import Foundation
import Observation

/// Coordinates simulator device states, app lifecycle execution, and error handling for the presentation layer.
///
/// All mutations and published properties are isolated to the main actor.
@Observable
@MainActor
final class SimulatorManager {
    /// The currently discovered simulator devices.
    var devices: [SimulatorDevice] = []

    /// Indicates whether a device fetch operation is currently ongoing.
    var isLoading: Bool = false

    /// The latest error message produced during device or app operations.
    var errorMessage: String?

    /// Set of application bundle identifiers currently running on the active booted device.
    var runningAppBundleIds: Set<String> = []

    private let simctlClient: SimctlClientProtocol

    /// Creates a simulator manager with an optional injected client.
    ///
    /// - Parameter simctlClient: The low-level simctl client implementation. Defaults to ``SimctlClient``.
    init(simctlClient: SimctlClientProtocol = SimctlClient()) {
        self.simctlClient = simctlClient
    }

    /// The localized display name of the simulator host application (e.g. "Simulator" or "Device Hub").
    var runnerAppName: String {
        simctlClient.runnerAppName
    }

    /// Asynchronously queries and refreshes the list of available simulator devices.
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

    /// Boots the specified simulator device and reloads the device list upon completion.
    ///
    /// - Parameter device: The target simulator device to boot.
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

    /// Shuts down the specified simulator device and refreshes the device list.
    ///
    /// - Parameter device: The target simulator device to shut down.
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

    /// Queries the running applications on the specified simulator device.
    ///
    /// - Parameter device: The simulator device to inspect. Must be in booted state.
    /// - Returns: A set of bundle identifiers currently executing on the device. Returns empty if device is not booted.
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

    /// Checks if an application is currently running on the given simulator device.
    ///
    /// - Parameters:
    ///   - device: The simulator device to inspect.
    ///   - bundleId: The bundle identifier to check.
    /// - Returns: `true` if the device is booted and the application process is running; otherwise `false`.
    func isAppRunning(device: SimulatorDevice, bundleId: String) -> Bool {
        guard device.state.isBooted else { return false }
        return runningAppBundleIds.contains(bundleId)
    }

    /// Launches an application on the simulator device and updates running process states.
    ///
    /// - Parameters:
    ///   - device: The target simulator device.
    ///   - bundleId: The bundle identifier of the application to launch.
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

    /// Terminates a running application on the simulator device and updates process states.
    ///
    /// - Parameters:
    ///   - device: The target simulator device.
    ///   - bundleId: The bundle identifier of the application to terminate.
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

    /// Opens the native macOS Simulator or Device Hub app window.
    ///
    /// - Parameter device: An optional target device to focus in the runner app.
    func openSimulatorApp(for device: SimulatorDevice? = nil) {
        simctlClient.openSimulatorApp(for: device?.udid)
    }

    /// Injects media files into the simulator's Photo Library.
    ///
    /// - Parameters:
    ///   - udid: The unique device identifier of the target simulator.
    ///   - mediaURLs: Array of local file URLs representing images or videos.
    /// - Throws: An error if media import fails.
    func addMedia(udid: String, mediaURLs: [URL]) async throws {
        try await simctlClient.addMedia(udid: udid, mediaURLs: mediaURLs)
    }
}
