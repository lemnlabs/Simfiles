//
//  SimulatorDevice.swift
//  Simfiles
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

/// The device kind used for customizing local storage labels (e.g. "On My iPhone" vs "On My iPad").
nonisolated enum LocalStorageDeviceKind: Sendable {
    case iphone
    case ipad
    case generic
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

    /// File URL to the device's shared app group containers directory (`Containers/Shared/AppGroup`).
    var sharedAppGroupContainersURL: URL {
        containersURL.appendingPathComponent("Shared/AppGroup")
    }

    /// Indicates whether this platform supports local file provider storage (iPhone, iPad, visionOS).
    var supportsLocalStorage: Bool {
        let lowerRuntime = runtimeIdentifier.lowercased()
        let lowerName = name.lowercased()
        if lowerRuntime.contains("watchos") || lowerRuntime.contains("tvos")
            || lowerName.contains("watch") || lowerName.contains("tv")
        {
            return false
        }
        return true
    }

    /// Classification of the device for local storage labels.
    var localStorageDeviceKind: LocalStorageDeviceKind {
        let lowerName = name.lowercased()
        if lowerName.contains("ipad") {
            return .ipad
        } else if lowerName.contains("iphone") {
            return .iphone
        }
        return .generic
    }

    /// Resolves the URL to the "File Provider Storage" directory inside the `group.com.apple.FileProvider.LocalStorage` container.
    var localStorageURL: URL? {
        let appGroupsURL = sharedAppGroupContainersURL
        guard FileManager.default.fileExists(atPath: appGroupsURL.path) else {
            return nil
        }

        guard
            let groupDirectories = try? FileManager.default.contentsOfDirectory(
                at: appGroupsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else {
            return nil
        }

        // 1. Preferred lookup: parse .com.apple.mobile_container_manager.metadata.plist for MCMMetadataIdentifier
        for groupDir in groupDirectories {
            let plistURL = groupDir.appendingPathComponent(
                ".com.apple.mobile_container_manager.metadata.plist"
            )
            if let data = try? Data(contentsOf: plistURL),
                let plist = try? PropertyListSerialization.propertyList(
                    from: data,
                    format: nil
                ) as? [String: Any],
                let identifier = plist["MCMMetadataIdentifier"] as? String,
                identifier == "group.com.apple.FileProvider.LocalStorage"
            {
                return groupDir.appendingPathComponent("File Provider Storage")
            }
        }

        // 2. Fallback: find any group directory containing "File Provider Storage"
        for groupDir in groupDirectories {
            let storageURL = groupDir.appendingPathComponent("File Provider Storage")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: storageURL.path, isDirectory: &isDirectory),
                isDirectory.boolValue
            {
                return storageURL
            }
        }

        return nil
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
