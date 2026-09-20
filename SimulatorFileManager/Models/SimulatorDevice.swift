//
//  SimulatorDevice.swift
//  SimulatorFileManager
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import Foundation

nonisolated enum DeviceState: String, Codable, CaseIterable, Sendable {
    case booted = "Booted"
    case shutdown = "Shutdown"
    case unknown = "Unknown"

    var isBooted: Bool {
        return self == .booted
    }
}

nonisolated struct SimulatorDevice: Identifiable, Hashable, Sendable {
    var id: String { udid }
    let udid: String
    let name: String
    let runtime: String
    let runtimeIdentifier: String
    let state: DeviceState
    let dataPath: String
    let dataPathSize: Int64?
    let lastUsedAt: Date?
    let deviceTypeIdentifier: String?

    var dataURL: URL {
        URL(fileURLWithPath: dataPath)
    }

    var containersURL: URL {
        dataURL.appendingPathComponent("Containers")
    }

    var bundleContainersURL: URL {
        containersURL.appendingPathComponent("Bundle/Application")
    }

    var dataContainersURL: URL {
        containersURL.appendingPathComponent("Data/Application")
    }

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
