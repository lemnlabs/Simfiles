//
//  SimctlClient.swift
//  SimulatorFileManager
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import AppKit
import Foundation

protocol SimctlClientProtocol: Sendable {
    func listDevices() async throws -> [SimulatorDevice]
    func bootDevice(udid: String) async throws
    func shutdownDevice(udid: String) async throws
    func fetchRunningAppBundleIds(udid: String) async throws -> Set<String>
    func launchApp(udid: String, bundleId: String) async throws
    func terminateApp(udid: String, bundleId: String) async throws
    func addMedia(udid: String, mediaURLs: [URL]) async throws
    func openSimulatorApp(for udid: String?)
    var runnerAppName: String { get }
}

nonisolated final class SimctlClient: SimctlClientProtocol, Sendable {
    init() {}

    var runnerAppName: String {
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.dt.Devices") != nil
        {
            return "Device Hub"
        }
        return "Simulator"
    }

    func listDevices() async throws -> [SimulatorDevice] {
        try await Task.detached(priority: .userInitiated) { () -> [SimulatorDevice] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl", "list", "devices", "available", "-j"]

            let pipe = Pipe()
            process.standardOutput = pipe
            let errorPipe = Pipe()
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown simctl error"
                throw NSError(
                    domain: "SimctlClient", code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: errMsg])
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let devicesDict = json?["devices"] as? [String: [[String: Any]]] else {
                return []
            }

            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fallbackIsoFormatter = ISO8601DateFormatter()

            var result: [SimulatorDevice] = []

            for (runtimeId, deviceList) in devicesDict {
                let friendlyRuntime = Self.formatRuntime(runtimeId)

                for raw in deviceList {
                    guard let udid = raw["udid"] as? String,
                        let name = raw["name"] as? String,
                        let stateStr = raw["state"] as? String,
                        let dataPath = raw["dataPath"] as? String
                    else {
                        continue
                    }

                    let state = DeviceState(rawValue: stateStr) ?? .unknown
                    let dataPathSize = raw["dataPathSize"] as? Int64
                    let deviceTypeIdentifier = raw["deviceTypeIdentifier"] as? String

                    var lastUsedAt: Date?
                    if let dateStr = raw["lastUsedAt"] as? String {
                        lastUsedAt =
                            isoFormatter.date(from: dateStr)
                            ?? fallbackIsoFormatter.date(from: dateStr)
                    }

                    let device = SimulatorDevice(
                        udid: udid,
                        name: name,
                        runtime: friendlyRuntime,
                        runtimeIdentifier: runtimeId,
                        state: state,
                        dataPath: dataPath,
                        dataPathSize: dataPathSize,
                        lastUsedAt: lastUsedAt,
                        deviceTypeIdentifier: deviceTypeIdentifier
                    )
                    result.append(device)
                }
            }

            // Sort booted devices first, then runtime descending, then by name
            result.sort { d1, d2 in
                if d1.state.isBooted != d2.state.isBooted {
                    return d1.state.isBooted && !d2.state.isBooted
                }
                if d1.runtime != d2.runtime {
                    return d1.runtime > d2.runtime
                }
                return d1.name < d2.name
            }

            return result
        }.value
    }

    func bootDevice(udid: String) async throws {
        try await runSimctl(arguments: ["boot", udid])
    }

    func shutdownDevice(udid: String) async throws {
        try await runSimctl(arguments: ["shutdown", udid])
    }

    func fetchRunningAppBundleIds(udid: String) async throws -> Set<String> {
        return try await Task.detached(priority: .userInitiated) { () -> Set<String> in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl", "spawn", udid, "launchctl", "list"]

            let pipe = Pipe()
            process.standardOutput = pipe
            let errorPipe = Pipe()
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                return []
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            var running = Set<String>()
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                let cols = line.split(whereSeparator: { $0.isWhitespace })
                guard cols.count >= 3 else { continue }

                let pidStr = String(cols[0])
                guard Int(pidStr) != nil else { continue }

                let label = String(cols[2])
                if label.hasPrefix("UIKitApplication:") {
                    let trimmed = label.dropFirst("UIKitApplication:".count)
                    if let bundleId = trimmed.split(separator: "[").first {
                        running.insert(String(bundleId))
                    }
                }
            }
            return running
        }.value
    }

    func launchApp(udid: String, bundleId: String) async throws {
        try await runSimctl(arguments: ["launch", udid, bundleId])
    }

    func terminateApp(udid: String, bundleId: String) async throws {
        try await runSimctl(arguments: ["terminate", udid, bundleId])
    }

    func addMedia(udid: String, mediaURLs: [URL]) async throws {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            var args = ["simctl", "addmedia", udid]
            args.append(contentsOf: mediaURLs.map { $0.path })
            process.arguments = args

            let errorPipe = Pipe()
            process.standardError = errorPipe
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8) ?? "Failed to add media"
                throw NSError(
                    domain: "SimctlClient", code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: errMsg])
            }
        }.value
    }

    func openSimulatorApp(for udid: String? = nil) {
        let appName =
            (NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.dt.Devices")
                != nil)
            ? "DeviceHub" : "Simulator"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        if let udid {
            process.arguments = ["-a", appName, "--args", "-CurrentDeviceUDID", udid]
        } else {
            process.arguments = ["-a", appName]
        }
        try? process.run()
    }

    private func runSimctl(arguments: [String]) async throws {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl"] + arguments
            let errorPipe = Pipe()
            process.standardError = errorPipe
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8) ?? "Command failed"
                throw NSError(
                    domain: "SimctlClient", code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: errMsg])
            }
        }.value
    }

    nonisolated private static func formatRuntime(_ runtimeId: String) -> String {
        // e.g. "com.apple.CoreSimulator.SimRuntime.iOS-27-0" -> "iOS 27.0"
        let prefix = "com.apple.CoreSimulator.SimRuntime."
        var raw = runtimeId
        if raw.hasPrefix(prefix) {
            raw.removeFirst(prefix.count)
        }
        let parts = raw.split(separator: "-")
        guard let osName = parts.first else { return runtimeId }
        let versionParts = parts.dropFirst()
        if versionParts.isEmpty {
            return String(osName)
        }
        return "\(osName) \(versionParts.joined(separator: "."))"
    }
}
