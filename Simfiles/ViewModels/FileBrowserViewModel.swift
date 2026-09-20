//
//  FileBrowserViewModel.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

/// Manages directory navigation, file manipulation, real-time monitoring, and clipboard operations for a selected app's sandbox.
@Observable
@MainActor
final class FileBrowserViewModel {
    /// The parent simulator device.
    let device: SimulatorDevice

    /// The application whose sandbox files are currently displayed.
    let app: InstalledApp

    /// The selected standard sandbox shortcut category (Documents, Library, tmp, Root).
    var selectedDirectory: SandboxDirectory = .root

    /// The absolute URL of the directory currently being viewed.
    var currentPathURL: URL

    private(set) var backStack: [URL] = []
    private(set) var forwardStack: [URL] = []
    private let maxHistoryCount = 50

    /// The items contained directly inside the current directory.
    var fileItems: [FileItem] = []

    /// Identifiers of currently selected items in the file table.
    var selectedItemIDs: Set<FileItem.ID> = []

    /// `true` when a drag operation is hovering over the file browser view.
    var isTargetedForDrop: Bool = false

    /// URL of the item currently being previewed via Quick Look.
    var previewURL: URL? = nil

    /// Flag controlling visibility of the error alert.
    var showingError: Bool = false

    /// The error message displayed in the error alert.
    var errorMessage: String = ""

    /// Flag controlling visibility of the create new folder modal dialog.
    var showingNewFolderDialog: Bool = false

    /// Input text binding for naming a new folder.
    var newFolderName: String = ""

    /// Flag controlling the delete confirmation modal.
    var showingDeleteConfirmation: Bool = false

    /// Items targeted for deletion while awaiting user confirmation.
    var itemsPendingDeletion: [FileItem] = []

    /// Indicates whether an app launch or terminate action is running.
    var isPerformingAppAction: Bool = false

    /// Active sort descriptor list for table columns.
    var sortOrder: [KeyPathComparator<FileItem>] = [
        KeyPathComparator(\.name, order: .forward)
    ]

    /// When true, directories are always displayed before regular files regardless of column sort order.
    var foldersAlwaysOnTop: Bool = true

    let fileService: FileManagerServiceProtocol
    let clipboardService: FileClipboardService
    let directoryMonitor: DirectoryMonitorProtocol
    private let simulatorManager: SimulatorManager?
    private let simctlClient: SimctlClientProtocol
    private let workspaceService: WorkspaceServiceProtocol
    private let pasteboardService: PasteboardServiceProtocol

    /// Initializes a file browser view model for the specified device and application.
    ///
    /// Starts live directory monitoring and initiates initial file loading.
    init(
        device: SimulatorDevice,
        app: InstalledApp,
        fileService: FileManagerServiceProtocol = FileManagerService(),
        clipboardService: FileClipboardService = FileClipboardService(),
        directoryMonitor: DirectoryMonitorProtocol = DirectoryMonitor(),
        simulatorManager: SimulatorManager? = nil,
        simctlClient: SimctlClientProtocol = SimctlClient(),
        workspaceService: WorkspaceServiceProtocol = WorkspaceService(),
        pasteboardService: PasteboardServiceProtocol = PasteboardService()
    ) {
        self.device = device
        self.app = app
        self.fileService = fileService
        self.clipboardService = clipboardService
        self.directoryMonitor = directoryMonitor
        self.simulatorManager = simulatorManager
        self.simctlClient = simctlClient
        self.workspaceService = workspaceService
        self.pasteboardService = pasteboardService
        self.currentPathURL = app.dataURL

        setupDirectoryMonitoring()
        reloadFiles()
    }

    // MARK: - Computed Properties

    /// The file items currently selected in the table.
    var selectedFiles: [FileItem] {
        fileItems.filter { selectedItemIDs.contains($0.id) }
    }

    /// Total cumulative byte size of all selected regular files.
    var selectedTotalSize: Int64 {
        selectedFiles.reduce(0) { $0 + ($1.isDirectory ? 0 : $1.size) }
    }

    /// Human-readable formatted string representing the selected file size total.
    var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedTotalSize, countStyle: .file)
    }

    /// File items sorted by the active sort descriptor and directory precedence.
    var sortedFileItems: [FileItem] {
        var items = fileItems
        items.sort(using: sortOrder)
        if foldersAlwaysOnTop {
            items.sort { i1, i2 in
                if i1.isDirectory != i2.isDirectory {
                    return i1.isDirectory && !i2.isDirectory
                }
                return false
            }
        }
        return items
    }

    /// `true` if the browser is currently at the root sandbox directory (`app.dataURL`).
    var isAtRootDirectory: Bool {
        let currentPath = currentPathURL.standardizedFileURL.path
        let rootPath = app.dataURL.standardizedFileURL.path
        guard currentPath != rootPath else { return true }
        let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return !currentPath.hasPrefix(rootPrefix)
    }

    /// `true` if previous navigation history is available.
    var canGoBack: Bool {
        !backStack.isEmpty
    }

    /// `true` if forward navigation history is available.
    var canGoForward: Bool {
        !forwardStack.isEmpty
    }

    /// `true` if the browser can navigate up to a parent folder within the sandbox.
    var canNavigateToParent: Bool {
        !isAtRootDirectory
    }

    /// A clean relative path string displayed in the path bar (e.g., `/Documents/subfolder`).
    var currentRelativePath: String {
        let base = baseDirectory(for: selectedDirectory)
        let basePath = base.standardizedFileURL.path
        let currPath = currentPathURL.standardizedFileURL.path
        if currPath == basePath {
            return "/\(selectedDirectory.rawValue)"
        }
        if currPath.hasPrefix(basePath) {
            let relative = String(currPath.dropFirst(basePath.count))
            return "/\(selectedDirectory.rawValue)\(relative)"
        }
        return currPath
    }

    /// `true` if the application process is running on the target simulator.
    var isAppRunning: Bool {
        simulatorManager?.isAppRunning(device: device, bundleId: app.bundleId) ?? false
    }

    var deleteConfirmationTitle: LocalizedStringResource {
        if itemsPendingDeletion.count == 1 {
            return .fileBrowserDeleteConfirmSingle(itemsPendingDeletion.first?.name ?? "")
        } else {
            return .fileBrowserDeleteConfirmMultiple(itemsPendingDeletion.count)
        }
    }

    // MARK: - Navigation

    /// An element in the interactive breadcrumb bar.
    struct PathBreadcrumb: Identifiable, Hashable {
        var id: String { url.path }
        let title: String
        let url: URL
    }

    /// Interactive hierarchical breadcrumb items representing the current path segments.
    var pathBreadcrumbs: [PathBreadcrumb] {
        let currentStandardized = currentPathURL.standardizedFileURL.path
        let rootDir = app.dataURL
        let rootStandardized = rootDir.standardizedFileURL.path
        let rootPrefix = rootStandardized.hasSuffix("/") ? rootStandardized : rootStandardized + "/"

        guard currentStandardized == rootStandardized || currentStandardized.hasPrefix(rootPrefix)
        else {
            return [PathBreadcrumb(title: currentPathURL.lastPathComponent, url: currentPathURL)]
        }

        var crumbs: [PathBreadcrumb] = [
            PathBreadcrumb(title: SandboxDirectory.root.rawValue, url: rootDir)
        ]

        if currentStandardized != rootStandardized {
            let relative = String(currentStandardized.dropFirst(rootPrefix.count))
            let components = relative.split(separator: "/").map(String.init)
            var accumulated = rootDir
            for component in components {
                accumulated = accumulated.appendingPathComponent(component)
                crumbs.append(PathBreadcrumb(title: component, url: accumulated))
            }
        }
        return crumbs
    }

    /// Resolves the base URL for the given standard sandbox directory.
    func baseDirectory(for dir: SandboxDirectory) -> URL {
        switch dir {
        case .documents: return app.documentsURL
        case .library: return app.libraryURL
        case .tmp: return app.tmpURL
        case .root: return app.dataURL
        }
    }

    /// Switches the browser view directly to a predefined sandbox directory.
    ///
    /// - Parameter dir: The destination standard sandbox folder.
    func switchDirectory(to dir: SandboxDirectory) {
        selectedDirectory = dir
        let targetURL = baseDirectory(for: dir)
        navigateToURL(targetURL)
    }

    /// Navigates to a specific directory URL and records navigation history.
    ///
    /// - Parameter url: The target directory URL.
    func navigateToURL(_ url: URL) {
        let targetPath = url.standardizedFileURL.path
        guard targetPath != currentPathURL.standardizedFileURL.path else { return }

        backStack.append(currentPathURL)
        if backStack.count > maxHistoryCount {
            backStack.removeFirst()
        }
        forwardStack.removeAll()
        applyNavigation(to: url)
    }

    /// Navigates back one step in the browser history.
    func goBack() {
        guard canGoBack else { return }
        let previousURL = backStack.removeLast()
        forwardStack.append(currentPathURL)
        if forwardStack.count > maxHistoryCount {
            forwardStack.removeFirst()
        }
        applyNavigation(to: previousURL)
    }

    /// Navigates forward one step in the browser history.
    func goForward() {
        guard canGoForward else { return }
        let nextURL = forwardStack.removeLast()
        backStack.append(currentPathURL)
        if backStack.count > maxHistoryCount {
            backStack.removeFirst()
        }
        applyNavigation(to: nextURL)
    }

    /// Navigates back to an arbitrary history entry in the back stack.
    ///
    /// - Parameter index: Target index in `backStack`.
    func navigateBack(to index: Int) {
        guard index >= 0 && index < backStack.count else { return }
        let targetURL = backStack[index]
        let itemsBetween = Array(backStack[(index + 1)...])
        backStack.removeSubrange(index...)
        forwardStack.append(currentPathURL)
        forwardStack.append(contentsOf: itemsBetween.reversed())
        if forwardStack.count > maxHistoryCount {
            let overflow = forwardStack.count - maxHistoryCount
            forwardStack.removeFirst(overflow)
        }
        applyNavigation(to: targetURL)
    }

    /// Navigates forward to an arbitrary history entry in the forward stack.
    ///
    /// - Parameter index: Target index in `forwardStack`.
    func navigateForward(to index: Int) {
        guard index >= 0 && index < forwardStack.count else { return }
        let targetURL = forwardStack[index]
        let itemsBetween = Array(forwardStack[(index + 1)...])
        forwardStack.removeSubrange(index...)
        backStack.append(currentPathURL)
        backStack.append(contentsOf: itemsBetween.reversed())
        if backStack.count > maxHistoryCount {
            let overflow = backStack.count - maxHistoryCount
            backStack.removeFirst(overflow)
        }
        applyNavigation(to: targetURL)
    }

    /// Navigates upward to the parent directory unless already at the root.
    func navigateToParent() {
        guard !isAtRootDirectory else { return }
        let parentURL = currentPathURL.deletingLastPathComponent()
        navigateToURL(parentURL)
    }

    /// Clears both back and forward history stacks.
    func clearHistory() {
        backStack.removeAll()
        forwardStack.removeAll()
    }

    private func applyNavigation(to url: URL) {
        selectedItemIDs.removeAll()
        currentPathURL = url
        updateSelectedDirectoryForCurrentPath()
        startMonitoring()
        reloadFiles()
    }

    private func updateSelectedDirectoryForCurrentPath() {
        let currentStandardized = currentPathURL.standardizedFileURL.path
        if currentStandardized.hasPrefix(app.documentsURL.standardizedFileURL.path) {
            selectedDirectory = .documents
        } else if currentStandardized.hasPrefix(app.libraryURL.standardizedFileURL.path) {
            selectedDirectory = .library
        } else if currentStandardized.hasPrefix(app.tmpURL.standardizedFileURL.path) {
            selectedDirectory = .tmp
        } else {
            selectedDirectory = .root
        }
    }

    func displayName(for url: URL) -> String {
        let standardized = url.standardizedFileURL.path
        if standardized == app.documentsURL.standardizedFileURL.path {
            return SandboxDirectory.documents.rawValue
        } else if standardized == app.libraryURL.standardizedFileURL.path {
            return SandboxDirectory.library.rawValue
        } else if standardized == app.tmpURL.standardizedFileURL.path {
            return SandboxDirectory.tmp.rawValue
        } else if standardized == app.dataURL.standardizedFileURL.path {
            return SandboxDirectory.root.rawValue
        } else {
            let name = url.lastPathComponent
            return name.isEmpty ? "/" : name
        }
    }

    func iconName(for url: URL) -> String {
        let standardized = url.standardizedFileURL.path
        if standardized == app.documentsURL.standardizedFileURL.path {
            return "doc.on.doc.fill"
        } else if standardized == app.libraryURL.standardizedFileURL.path {
            return "books.vertical.fill"
        } else if standardized == app.tmpURL.standardizedFileURL.path {
            return "clock.arrow.circlepath"
        } else {
            return "folder.fill"
        }
    }

    /// Toggles the Quick Look panel for the first selected non-directory file item.
    func toggleQuickLook() {
        if previewURL != nil {
            previewURL = nil
        } else if let first = selectedFiles.first, !first.isDirectory {
            previewURL = first.url
        }
    }

    /// Copies the current directory's file system path to the system pasteboard.
    func copyCurrentPath() {
        pasteboardService.copyString(currentPathURL.path)
    }

    /// Opens macOS Terminal at the current directory location.
    func openInTerminal() {
        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open(
            [currentPathURL],
            withApplicationAt: terminalURL,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }

    /// Reloads the directory contents from disk and discards stale selection identifiers.
    func reloadFiles() {
        fileItems = fileService.listFiles(at: currentPathURL)
        let validIDs = Set(fileItems.map(\.id))
        selectedItemIDs.formIntersection(validIDs)
    }

    // MARK: - Directory Monitoring

    private func setupDirectoryMonitoring() {
        directoryMonitor.onDirectoryChanged = { [weak self] in
            Task { @MainActor [weak self] in
                self?.reloadFiles()
            }
        }
        startMonitoring()
    }

    /// Starts observing filesystem modification events on `currentPathURL`.
    func startMonitoring() {
        directoryMonitor.startMonitoring(url: currentPathURL)
    }

    /// Stops observing filesystem modification events.
    func stopMonitoring() {
        directoryMonitor.stopMonitoring()
    }

    /// Handles double-click user interaction: navigates into directories or opens files in default apps.
    ///
    /// - Parameter item: The clicked file item.
    func handleDoubleClick(on item: FileItem) {
        if item.isDirectory {
            navigateToURL(item.url)
        } else {
            workspaceService.openItem(url: item.url)
        }
    }

    // MARK: - Clipboard & CRUD

    /// Resolves the items to act upon when a context menu or shortcut is invoked on a table row.
    func itemsToActOn(for clickedItem: FileItem) -> [FileItem] {
        if selectedItemIDs.contains(clickedItem.id) {
            return selectedFiles
        } else {
            return [clickedItem]
        }
    }

    /// Places the selected items into the in-memory clipboard for a copy operation.
    ///
    /// - Parameter items: The items to copy.
    func copyItems(_ items: [FileItem]) {
        clipboardService.copy(urls: items.map(\.url))
    }

    /// Places the selected items into the in-memory clipboard for a cut (relocation) operation.
    ///
    /// - Parameter items: The items to cut.
    func cutItems(_ items: [FileItem]) {
        clipboardService.cut(urls: items.map(\.url))
    }

    /// Pastes the clipboard files into the specified directory.
    ///
    /// - Parameter destination: The directory receiving the files.
    func pasteClipboard(to destination: URL) {
        guard !clipboardService.isEmpty else { return }
        do {
            if clipboardService.isCut {
                try fileService.moveFiles(from: clipboardService.urls, to: destination)
                clipboardService.clear()
            } else {
                try fileService.copyFiles(from: clipboardService.urls, to: destination)
            }
            reloadFiles()
        } catch {
            showError(
                String(localized: .fileBrowserErrorPasteFailed(error.localizedDescription))
            )
        }
    }

    /// Copies the absolute filesystem paths of the specified items to the system pasteboard.
    ///
    /// - Parameter items: The items whose paths should be copied.
    func copyPaths(for items: [FileItem]) {
        pasteboardService.copyStrings(items.map(\.url.path))
    }

    /// Initiates deletion flow by prompting the user for confirmation.
    ///
    /// - Parameter items: The items targeted for deletion.
    func confirmDelete(items: [FileItem]) {
        guard !items.isEmpty else { return }
        itemsPendingDeletion = items
        showingDeleteConfirmation = true
    }

    /// Executes the pending deletion, safely moving the items to the macOS Trash.
    func executeDelete() {
        let items = itemsPendingDeletion
        itemsPendingDeletion = []
        showingDeleteConfirmation = false
        guard !items.isEmpty else { return }
        do {
            try fileService.deleteItems(at: items.map(\.url))
            selectedItemIDs.subtract(items.map(\.id))
            reloadFiles()
        } catch {
            showError(
                String(localized: .fileBrowserErrorDeleteFailed(error.localizedDescription))
            )
        }
    }

    /// Cancels the pending deletion and clears targeted items.
    func cancelDelete() {
        itemsPendingDeletion = []
    }

    /// Creates a new directory inside the current path with the name entered in `newFolderName`.
    func createFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newDirURL = currentPathURL.appendingPathComponent(trimmed)
        do {
            try fileService.createDirectory(at: newDirURL)
            showingNewFolderDialog = false
            newFolderName = ""
            reloadFiles()
        } catch {
            showError(
                String(localized: .fileBrowserErrorCreateFolderFailed(error.localizedDescription))
            )
        }
    }

    /// Moves the specified items into a target destination directory.
    ///
    /// - Parameters:
    ///   - items: The items to move.
    ///   - destination: The directory into which the items should be moved.
    func moveItems(_ items: [FileItem], to destination: URL) {
        guard !items.isEmpty else { return }
        do {
            try fileService.moveFiles(from: items.map(\.url), to: destination)
            selectedItemIDs.removeAll()
            reloadFiles()
        } catch {
            showError(
                String(localized: .fileBrowserErrorMoveFailed(error.localizedDescription))
            )
        }
    }

    /// Prompts the user with an open panel to select a folder destination and moves the items there.
    ///
    /// - Parameter items: The items to move.
    func promptMove(items: [FileItem]) {
        guard !items.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: .fileBrowserPanelMoveHere)
        panel.directoryURL = currentPathURL

        if panel.runModal() == .OK, let destination = panel.url {
            moveItems(items, to: destination)
        }
    }

    // MARK: - Open / Reveal

    /// Reveals the current directory in macOS Finder.
    func openInFinder() {
        workspaceService.revealInFinder(url: currentPathURL)
    }

    /// Reveals the specified items in macOS Finder.
    ///
    /// - Parameter items: The items to reveal.
    func revealInFinder(items: [FileItem]) {
        workspaceService.revealInFinder(urls: items.map(\.url))
    }

    // MARK: - Import & Drag/Drop

    /// Displays an open panel allowing the user to select external files/folders to copy into the current directory.
    func selectFileToImport() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: .fileBrowserPanelImport)

        if panel.runModal() == .OK {
            do {
                try fileService.importFiles(from: panel.urls, to: currentPathURL)
                reloadFiles()
            } catch {
                showError(
                    String(localized: .fileBrowserErrorCopyFailed(error.localizedDescription))
                )
            }
        }
    }

    /// Displays an open panel allowing the user to select media files to import into the simulator's Photo Library.
    func selectMediaToImport() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image, .movie, .video]
        panel.prompt = String(localized: .fileBrowserPanelAddToPhotos)

        if panel.runModal() == .OK {
            Task {
                do {
                    try await simctlClient.addMedia(udid: device.udid, mediaURLs: panel.urls)
                } catch {
                    showError(
                        String(
                            localized: .fileBrowserErrorAddMediaFailed(error.localizedDescription))
                    )
                }
            }
        }
    }

    /// Processes items dropped from macOS drag-and-drop operations.
    ///
    /// Distinguishes between internal reordering/moving within the same browser and external file importing.
    /// - Parameters:
    ///   - providers: The item providers transferred by the drop operation.
    ///   - targetDirectory: The destination directory. Defaults to `currentPathURL` if nil.
    /// - Returns: `true` if the drop operation was handled.
    func handleDrop(providers: [NSItemProvider], targetDirectory: URL? = nil) -> Bool {
        let destDir = targetDirectory ?? currentPathURL

        Task {
            var urlsToProcess: [URL] = []

            for provider in providers {
                if let item = try? await provider.loadItem(
                    forTypeIdentifier: UTType.fileURL.identifier)
                {
                    if let data = item as? Data,
                        let url = URL(dataRepresentation: data, relativeTo: nil)
                    {
                        urlsToProcess.append(url)
                    } else if let url = item as? URL {
                        urlsToProcess.append(url)
                    }
                }
            }

            guard !urlsToProcess.isEmpty else { return }
            do {
                let currentPaths = Set(fileItems.map(\.url.standardizedFileURL.path))
                let isMovingCurrentFiles = urlsToProcess.allSatisfy {
                    currentPaths.contains($0.standardizedFileURL.path)
                }

                if isMovingCurrentFiles {
                    try fileService.moveFiles(from: urlsToProcess, to: destDir)
                    selectedItemIDs.removeAll()
                } else {
                    try fileService.importFiles(from: urlsToProcess, to: destDir)
                }
                reloadFiles()
            } catch {
                showError(
                    String(localized: .fileBrowserErrorProcessFailed(error.localizedDescription))
                )
            }
        }

        return true
    }

    // MARK: - App Actions

    /// Launches the app if stopped, or terminates it if running on the simulator.
    func toggleAppExecution() {
        Task {
            isPerformingAppAction = true
            if isAppRunning {
                await simulatorManager?.terminateApp(device: device, bundleId: app.bundleId)
            } else {
                await simulatorManager?.launchApp(device: device, bundleId: app.bundleId)
            }
            isPerformingAppAction = false
        }
    }

    // MARK: - Helpers

    /// Checks whether the active sort order matches the given keypath.
    func isSortedBy<T>(_ keyPath: KeyPath<FileItem, T>) -> Bool {
        guard let first = sortOrder.first else { return false }
        return first.keyPath == keyPath
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}
