//
//  SimctlClient.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import AppKit
import Foundation

/// Defines low-level operations for communicating with Xcode simulators via `simctl`.
protocol SimctlClientProtocol: Sendable {
    /// Retrieves a list of available simulator devices installed on the system.
    ///
    /// - Returns: An array of ``SimulatorDevice`` instances sorted by boot state, runtime, and name.
    /// - Throws: An `NSError` if the underlying `xcrun simctl` command fails.
    func listDevices() async throws -> [SimulatorDevice]

    /// Boots the simulator device identified by the given UDID.
    ///
    /// - Parameter udid: The unique device identifier of the target simulator.
    /// - Throws: An `NSError` if the simulator fails to boot.
    func bootDevice(udid: String) async throws

    /// Shuts down the simulator device identified by the given UDID.
    ///
    /// - Parameter udid: The unique device identifier of the target simulator.
    /// - Throws: An `NSError` if the shutdown command fails.
    func shutdownDevice(udid: String) async throws

    /// Fetches the bundle identifiers of user applications currently running on the specified booted simulator.
    ///
    /// - Parameter udid: The unique device identifier of the booted target simulator.
    /// - Returns: A set of bundle identifiers currently active on the simulator.
    /// - Throws: An `NSError` if querying the process list fails.
    func fetchRunningAppBundleIds(udid: String) async throws -> Set<String>

    /// Launches an application with the specified bundle identifier on the target simulator.
    ///
    /// - Parameters:
    ///   - udid: The unique device identifier of the target simulator.
    ///   - bundleId: The bundle identifier of the application to launch.
    /// - Throws: An `NSError` if the application fails to launch.
    func launchApp(udid: String, bundleId: String) async throws

    /// Terminates the running application with the specified bundle identifier on the target simulator.
    ///
    /// - Parameters:
    ///   - udid: The unique device identifier of the target simulator.
    ///   - bundleId: The bundle identifier of the application to terminate.
    /// - Throws: An `NSError` if termination fails.
    func terminateApp(udid: String, bundleId: String) async throws

    /// Adds photo or video media files to the simulator's photo library.
    ///
    /// - Parameters:
    ///   - udid: The unique device identifier of the target simulator.
    ///   - mediaURLs: File URLs of the media files to inject.
    /// - Throws: An `NSError` if `simctl addmedia` exits with a non-zero status.
    func addMedia(udid: String, mediaURLs: [URL]) async throws

    /// Opens the official Simulator.app or Device Hub application on macOS.
    ///
    /// - Parameter udid: An optional device UDID to bring to focus upon opening.
    func openSimulatorApp(for udid: String?)

    /// Returns the localized display name of the simulator runner app (`Simulator` or `Device Hub`).
    var runnerAppName: String { get }
}

/// Communicates directly with the `xcrun simctl` command-line utility.
///
/// Executes background CLI tasks via `Task.detached` to avoid blocking the caller's execution thread.
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
