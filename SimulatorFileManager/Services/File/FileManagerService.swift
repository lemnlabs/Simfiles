//
//  FileManagerService.swift
//  SimulatorFileManager
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

protocol FileManagerServiceProtocol: Sendable {
    func listFiles(at directoryURL: URL) -> [FileItem]
    @discardableResult
    func importFiles(from sourceURLs: [URL], to destinationDirectory: URL) throws -> [URL]
    @discardableResult
    func copyFiles(from sourceURLs: [URL], to destinationDirectory: URL) throws -> [URL]
    @discardableResult
    func moveFiles(from sourceURLs: [URL], to destinationDirectory: URL) throws -> [URL]
    func deleteItem(at url: URL) throws
    func deleteItems(at urls: [URL]) throws
    func createDirectory(at url: URL) throws
}

nonisolated final class FileManagerService: FileManagerServiceProtocol, Sendable {
    init() {}

    func listFiles(at directoryURL: URL) -> [FileItem] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return []
        }

        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .contentTypeKey,
        ]
        guard
            let entries = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        var items: [FileItem] = []

        for fileURL in entries {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                continue
            }

            let isDirectory = resourceValues.isDirectory ?? false
            let size = Int64(resourceValues.fileSize ?? 0)
            let modDate = resourceValues.contentModificationDate
            let contentType = resourceValues.contentType

            let item = FileItem(
                url: fileURL,
                isDirectory: isDirectory,
                size: size,
                modificationDate: modDate,
                contentType: contentType
            )
            items.append(item)
        }

        return items
    }

    @discardableResult
    func importFiles(from sourceURLs: [URL], to destinationDirectory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: destinationDirectory.path) {
            try fileManager.createDirectory(
                at: destinationDirectory, withIntermediateDirectories: true)
        }

        var importedURLs: [URL] = []

        for sourceURL in sourceURLs {
            let fileName = sourceURL.lastPathComponent
            var targetURL = destinationDirectory.appendingPathComponent(fileName)

            // Generate unique filename if duplicate exists
            if fileManager.fileExists(atPath: targetURL.path) {
                targetURL = uniqueURL(for: targetURL, in: destinationDirectory)
            }

            try fileManager.copyItem(at: sourceURL, to: targetURL)
            importedURLs.append(targetURL)
        }

        return importedURLs
    }

    func deleteItem(at url: URL) throws {
        // Safely move to Trash
        var resultURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
    }

    func deleteItems(at urls: [URL]) throws {
        for url in urls {
            try deleteItem(at: url)
        }
    }

    @discardableResult
    func moveFiles(from sourceURLs: [URL], to destinationDirectory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: destinationDirectory.path) {
            try fileManager.createDirectory(
                at: destinationDirectory, withIntermediateDirectories: true)
        }

        let destStandardPath = destinationDirectory.standardizedFileURL.path
        var movedURLs: [URL] = []

        for sourceURL in sourceURLs {
            let sourceStandardPath = sourceURL.standardizedFileURL.path

            // Prevent moving a parent folder into its own child folder
            if destStandardPath == sourceStandardPath
                || destStandardPath.hasPrefix(sourceStandardPath + "/")
            {
                throw NSError(
                    domain: "FileManagerService",
                    code: 1001,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            String(
                                localized: .fileServiceErrorRecursiveMove(
                                    sourceURL.lastPathComponent)
                            )
                    ]
                )
            }

            let fileName = sourceURL.lastPathComponent
            var targetURL = destinationDirectory.appendingPathComponent(fileName)

            // Skip if already in the same location
            if sourceStandardPath == targetURL.standardizedFileURL.path {
                continue
            }

            // Generate unique filename if duplicate exists at destination
            if fileManager.fileExists(atPath: targetURL.path) {
                targetURL = uniqueURL(for: targetURL, in: destinationDirectory)
            }

            try fileManager.moveItem(at: sourceURL, to: targetURL)
            movedURLs.append(targetURL)
        }

        return movedURLs
    }

    @discardableResult
    func copyFiles(from sourceURLs: [URL], to destinationDirectory: URL) throws -> [URL] {
        try importFiles(from: sourceURLs, to: destinationDirectory)
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    // MARK: - Legacy Forwarding (For transition compatibility)

    @MainActor
    func revealInFinder(urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    @MainActor
    func revealInFinder(url: URL) {
        revealInFinder(urls: [url])
    }

    @MainActor
    func openItem(url: URL) {
        NSWorkspace.shared.open(url)
    }

    func addMediaToSimulator(udid: String, mediaURLs: [URL]) async throws {
        try await SimctlClient().addMedia(udid: udid, mediaURLs: mediaURLs)
    }

    private func uniqueURL(for targetURL: URL, in directory: URL) -> URL {
        let fileManager = FileManager.default
        let baseName = targetURL.deletingPathExtension().lastPathComponent
        let ext = targetURL.pathExtension
        var counter = 1

        while true {
            let newName = ext.isEmpty ? "\(baseName) \(counter)" : "\(baseName) \(counter).\(ext)"
            let candidate = directory.appendingPathComponent(newName)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            counter += 1
        }
    }
}
