//
//  SimulatorDevice.swift
//  SimulatorFileManager
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import Foundation

/// Represents the runtime lifecycle state of an Apple simulator device.
nonisolated enum DeviceState: String, Codable, CaseIterable, Sendable {
    case booted = "Booted"
    case shutdown = "Shutdown"
    case unknown = "Unknown"

    /// `true` if the device is currently running and booted.
    var isBooted: Bool {
        return self == .booted
    }
}

/// Represents an Apple platform simulator device discovered on the local machine.
nonisolated struct SimulatorDevice: Identifiable, Hashable, Sendable {
    var id: String { udid }

    /// The unique device identifier (UUID string).
    let udid: String

    /// The display name of the simulator (e.g., "iPhone 16 Pro").
    let name: String

    /// The formatted human-readable runtime description (e.g., "iOS 18.2").
    let runtime: String

    /// The raw CoreSimulator runtime identifier (e.g., `com.apple.CoreSimulator.SimRuntime.iOS-18-2`).
    let runtimeIdentifier: String

    /// The current boot state of the simulator.
    let state: DeviceState

    /// The absolute filesystem path to the simulator's data directory.
    let dataPath: String

    /// The total disk size in bytes consumed by the device data path, if available.
    let dataPathSize: Int64?

    /// The timestamp when the simulator was last accessed or booted.
    let lastUsedAt: Date?

    /// The simulator device type identifier (e.g., `com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro`).
    let deviceTypeIdentifier: String?

    /// File URL to the root data folder of this simulator.
    var dataURL: URL {
        URL(fileURLWithPath: dataPath)
    }

    /// File URL to the `Containers` subdirectory.
    var containersURL: URL {
        dataURL.appendingPathComponent("Containers")
    }

    /// File URL to installed application bundle containers (`Containers/Bundle/Application`).
    var bundleContainersURL: URL {
        containersURL.appendingPathComponent("Bundle/Application")
    }

    /// File URL to application data containers (`Containers/Data/Application`).
    var dataContainersURL: URL {
        containersURL.appendingPathComponent("Data/Application")
    }

    /// File URL to the device's shared media directory.
    var mediaURL: URL {
        dataURL.appendingPathComponent("Media")
    }

    init(
        udid: String,
        name: String,
        runtime: String,
        runtimeIdentifier: String,
        state: DeviceState,
        dataPath: String,
        dataPathSize: Int64? = nil,
        lastUsedAt: Date? = nil,
        deviceTypeIdentifier: String? = nil
    ) {
        self.udid = udid
        self.name = name
        self.runtime = runtime
        self.runtimeIdentifier = runtimeIdentifier
        self.state = state
        self.dataPath = dataPath
        self.dataPathSize = dataPathSize
        self.lastUsedAt = lastUsedAt
        self.deviceTypeIdentifier = deviceTypeIdentifier
    }
}
