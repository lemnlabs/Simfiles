//
//  AppScanner.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import AppKit
import Foundation

/// Scans the file system of a simulator device to locate installed applications and their sandbox containers.
///
/// Discovers both user-installed applications and system applications by inspecting
/// `Containers/Bundle/Application` and `Containers/Data/Application` directories.
nonisolated final class AppScanner: Sendable {
    init() {}

    /// Internal metadata representing an application's bundle content.
    nonisolated struct AppBundleInfo: Sendable {
        let bundleId: String
        let displayName: String
        let version: String
        let bundleURL: URL
        let iconData: Data?
    }

    /// Scans installed applications for the specified simulator device.
    ///
    /// Reads container metadata plists (`.com.apple.mobile_container_manager.metadata.plist`)
    /// and resolves corresponding `.app` bundles to extract display names, versions, and icons.
    ///
    /// - Parameter device: The simulator device whose installed applications should be scanned.
    /// - Returns: An array of ``InstalledApp`` models sorted with user apps first, followed alphabetically by display name.
    func scanInstalledApps(for device: SimulatorDevice) async -> [InstalledApp] {
        return await Task.detached(priority: .userInitiated) { () -> [InstalledApp] in
            let fileManager = FileManager.default

            // 1. Scan Bundle/Application
            let bundleMap = self.scanBundleApplications(
                device: device,
                fileManager: fileManager
            )

            // 2. Scan Data/Application
            let dataContainersURL = device.dataContainersURL
            guard
                let dataEntries = try? fileManager.contentsOfDirectory(
                    at: dataContainersURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
            else {
                return []
            }

            var apps: [InstalledApp] = []
            var seenBundleIds = Set<String>()

            for folderURL in dataEntries {
                let metadataURL = folderURL.appendingPathComponent(
                    ".com.apple.mobile_container_manager.metadata.plist")
                guard fileManager.fileExists(atPath: metadataURL.path),
                    let metadataData = try? Data(contentsOf: metadataURL),
                    let plist = try? PropertyListSerialization.propertyList(
                        from: metadataData, options: [], format: nil) as? [String: Any],
                    let bundleId = plist["MCMMetadataIdentifier"] as? String
                else {
                    continue
                }

                guard !seenBundleIds.contains(bundleId) else { continue }
                seenBundleIds.insert(bundleId)

                let isSystem = bundleId.hasPrefix("com.apple.")
                let bundleInfo = bundleMap[bundleId]

                let displayName: String
                let version: String
                let bundleURL: URL?
                let iconData: Data?

                if let bundleInfo {
                    displayName = bundleInfo.displayName
                    version = bundleInfo.version
                    bundleURL = bundleInfo.bundleURL
                    iconData = bundleInfo.iconData
                } else {
                    displayName = self.fallbackDisplayName(for: bundleId)
                    version = "--"
                    bundleURL = nil
                    iconData = nil
                }

                let app = InstalledApp(
                    bundleId: bundleId,
                    displayName: displayName,
                    version: version,
                    bundleURL: bundleURL,
                    dataURL: folderURL,
                    isSystemApp: isSystem,
                    iconData: iconData
                )
                apps.append(app)
            }

            // Sort user apps first, then alphabetically by app name
            apps.sort { a1, a2 in
                if a1.isSystemApp != a2.isSystemApp {
                    return !a1.isSystemApp && a2.isSystemApp
                }
                return a1.displayName.localizedCaseInsensitiveCompare(a2.displayName)
                    == .orderedAscending
            }

            return apps
        }.value
    }

    private func scanBundleApplications(device: SimulatorDevice, fileManager: FileManager)
        -> [String:
        AppBundleInfo]
    {
        let bundleContainersURL = device.bundleContainersURL
        guard
            let bundleEntries = try? fileManager.contentsOfDirectory(
                at: bundleContainersURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return [:]
        }

        var map: [String: AppBundleInfo] = [:]

        for folderURL in bundleEntries {
            guard
                let subItems = try? fileManager.contentsOfDirectory(
                    at: folderURL, includingPropertiesForKeys: nil)
            else {
                continue
            }

            // Find .app bundle directory
            guard let appURL = subItems.first(where: { $0.pathExtension == "app" }) else {
                continue
            }

            let infoPlistURL = appURL.appendingPathComponent("Info.plist")
            guard let plistData = try? Data(contentsOf: infoPlistURL),
                let plist = try? PropertyListSerialization.propertyList(
                    from: plistData, options: [], format: nil) as? [String: Any],
                let bundleId = plist["CFBundleIdentifier"] as? String
            else {
                continue
            }

            let displayName =
                (plist["CFBundleDisplayName"] as? String)
                ?? (plist["CFBundleName"] as? String)
                ?? appURL.deletingPathExtension().lastPathComponent

            let shortVersion = plist["CFBundleShortVersionString"] as? String ?? ""
            let bundleVersion = plist["CFBundleVersion"] as? String ?? ""
            let version =
                [shortVersion, bundleVersion].filter { !$0.isEmpty }.joined(separator: " (")
                + (bundleVersion.isEmpty ? "" : ")")

            let iconData = extractAppIcon(from: appURL, plist: plist, fileManager: fileManager)

            let info = AppBundleInfo(
                bundleId: bundleId,
                displayName: displayName,
                version: version.isEmpty ? "1.0" : version,
                bundleURL: appURL,
                iconData: iconData
            )
            map[bundleId] = info
        }

        return map
    }

    private func extractAppIcon(from appURL: URL, plist: [String: Any], fileManager: FileManager)
        -> Data?
    {
        // CFBundleIcons -> CFBundlePrimaryIcon -> CFBundleIconFiles
        var candidateNames: [String] = []
        if let icons = plist["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String]
        {
            candidateNames.append(contentsOf: files.reversed())
        }

        if let iconFile = plist["CFBundleIconFile"] as? String {
            candidateNames.append(iconFile)
        }

        // Search AppIcon*.png files in directory
        if let appContents = try? fileManager.contentsOfDirectory(
            at: appURL, includingPropertiesForKeys: nil)
        {
            for fileURL in appContents
            where fileURL.lastPathComponent.contains("AppIcon") && fileURL.pathExtension == "png" {
                if let data = try? Data(contentsOf: fileURL) {
                    return data
                }
            }
        }

        for name in candidateNames {
            let possibleURL = appURL.appending(component: name)
            if fileManager.fileExists(atPath: possibleURL.path),
                let data = try? Data(contentsOf: possibleURL)
            {
                return data
            }
            let pngURL = appURL.appending(component: name).appendingPathExtension("png")
            if fileManager.fileExists(atPath: pngURL.path), let data = try? Data(contentsOf: pngURL)
            {
                return data
            }
            let png2xURL = appURL.appending(component: "\(name)@2x").appendingPathExtension("png")
            if fileManager.fileExists(atPath: png2xURL.path),
                let data = try? Data(contentsOf: png2xURL)
            {
                return data
            }
        }

        return nil
    }

    private func fallbackDisplayName(for bundleId: String) -> String {
        let components = bundleId.split(separator: ".")
        if let last = components.last {
            return String(last)
        }
        return bundleId
    }
}
