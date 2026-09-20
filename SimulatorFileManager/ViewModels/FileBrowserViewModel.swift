import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class FileBrowserViewModel {
    let device: SimulatorDevice
    let app: InstalledApp

    var selectedDirectory: SandboxDirectory = .root
    var currentPathURL: URL
    private(set) var backStack: [URL] = []
    private(set) var forwardStack: [URL] = []
    private let maxHistoryCount = 50
    var fileItems: [FileItem] = []
    var selectedItemIDs: Set<FileItem.ID> = []
    var isTargetedForDrop: Bool = false
    var previewURL: URL? = nil

    var showingError: Bool = false
    var errorMessage: String = ""

    var showingNewFolderDialog: Bool = false
    var newFolderName: String = ""

    var showingDeleteConfirmation: Bool = false
    var itemsPendingDeletion: [FileItem] = []

    var isPerformingAppAction: Bool = false
    var sortOrder: [KeyPathComparator<FileItem>] = [
        KeyPathComparator(\.name, order: .forward)
    ]
    var foldersAlwaysOnTop: Bool = true

    let fileService: FileManagerServiceProtocol
    let clipboardService: FileClipboardService
    let directoryMonitor: DirectoryMonitorProtocol
    private let simulatorManager: SimulatorManager?
    private let simctlClient: SimctlClientProtocol
    private let workspaceService: WorkspaceServiceProtocol
    private let pasteboardService: PasteboardServiceProtocol

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

    var selectedFiles: [FileItem] {
        fileItems.filter { selectedItemIDs.contains($0.id) }
    }

    var selectedTotalSize: Int64 {
        selectedFiles.reduce(0) { $0 + ($1.isDirectory ? 0 : $1.size) }
    }

    var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedTotalSize, countStyle: .file)
    }

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

    var isAtRootDirectory: Bool {
        let base = baseDirectory(for: selectedDirectory)
        return currentPathURL.standardizedFileURL.path == base.standardizedFileURL.path
    }

    var canGoBack: Bool {
        !backStack.isEmpty
    }

    var canGoForward: Bool {
        !forwardStack.isEmpty
    }

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

    struct PathBreadcrumb: Identifiable, Hashable {
        var id: String { url.path }
        let title: String
        let url: URL
    }

    var pathBreadcrumbs: [PathBreadcrumb] {
        let currentStandardized = currentPathURL.standardizedFileURL.path

        let baseDir: URL
        let rootTitle: String

        if currentStandardized.hasPrefix(app.documentsURL.standardizedFileURL.path) {
            baseDir = app.documentsURL
            rootTitle = SandboxDirectory.documents.rawValue
        } else if currentStandardized.hasPrefix(app.libraryURL.standardizedFileURL.path) {
            baseDir = app.libraryURL
            rootTitle = SandboxDirectory.library.rawValue
        } else if currentStandardized.hasPrefix(app.tmpURL.standardizedFileURL.path) {
            baseDir = app.tmpURL
            rootTitle = SandboxDirectory.tmp.rawValue
        } else {
            baseDir = app.dataURL
            rootTitle = SandboxDirectory.root.rawValue
        }

        var crumbs: [PathBreadcrumb] = [
            PathBreadcrumb(title: rootTitle, url: baseDir)
        ]

        let basePath = baseDir.standardizedFileURL.path
        if currentStandardized.hasPrefix(basePath) && currentStandardized != basePath {
            let relative = String(currentStandardized.dropFirst(basePath.count))
            let components = relative.split(separator: "/").map(String.init)
            var accumulated = baseDir
            for component in components {
                accumulated = accumulated.appendingPathComponent(component)
                crumbs.append(PathBreadcrumb(title: component, url: accumulated))
            }
        }
        return crumbs
    }

    func baseDirectory(for dir: SandboxDirectory) -> URL {
        switch dir {
        case .documents: return app.documentsURL
        case .library: return app.libraryURL
        case .tmp: return app.tmpURL
        case .root: return app.dataURL
        }
    }

    func switchDirectory(to dir: SandboxDirectory) {
        selectedDirectory = dir
        let targetURL = baseDirectory(for: dir)
        navigateToURL(targetURL)
    }

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

    func goBack() {
        guard canGoBack else { return }
        let previousURL = backStack.removeLast()
        forwardStack.append(currentPathURL)
        if forwardStack.count > maxHistoryCount {
            forwardStack.removeFirst()
        }
        applyNavigation(to: previousURL)
    }

    func goForward() {
        guard canGoForward else { return }
        let nextURL = forwardStack.removeLast()
        backStack.append(currentPathURL)
        if backStack.count > maxHistoryCount {
            backStack.removeFirst()
        }
        applyNavigation(to: nextURL)
    }

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

    func navigateToParent() {
        guard !isAtRootDirectory else { return }
        let parentURL = currentPathURL.deletingLastPathComponent()
        navigateToURL(parentURL)
    }

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

    func toggleQuickLook() {
        if previewURL != nil {
            previewURL = nil
        } else if let first = selectedFiles.first, !first.isDirectory {
            previewURL = first.url
        }
    }

    func copyCurrentPath() {
        pasteboardService.copyString(currentPathURL.path)
    }

    func openInTerminal() {
        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open(
            [currentPathURL],
            withApplicationAt: terminalURL,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }

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

    func startMonitoring() {
        directoryMonitor.startMonitoring(url: currentPathURL)
    }

    func stopMonitoring() {
        directoryMonitor.stopMonitoring()
    }

    func handleDoubleClick(on item: FileItem) {
        if item.isDirectory {
            navigateToURL(item.url)
        } else {
            workspaceService.openItem(url: item.url)
        }
    }

    // MARK: - Clipboard & CRUD

    func itemsToActOn(for clickedItem: FileItem) -> [FileItem] {
        if selectedItemIDs.contains(clickedItem.id) {
            return selectedFiles
        } else {
            return [clickedItem]
        }
    }

    func copyItems(_ items: [FileItem]) {
        clipboardService.copy(urls: items.map(\.url))
    }

    func cutItems(_ items: [FileItem]) {
        clipboardService.cut(urls: items.map(\.url))
    }

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

    func copyPaths(for items: [FileItem]) {
        pasteboardService.copyStrings(items.map(\.url.path))
    }

    func confirmDelete(items: [FileItem]) {
        guard !items.isEmpty else { return }
        itemsPendingDeletion = items
        showingDeleteConfirmation = true
    }

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

    func cancelDelete() {
        itemsPendingDeletion = []
    }

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

    func openInFinder() {
        workspaceService.revealInFinder(url: currentPathURL)
    }

    func revealInFinder(items: [FileItem]) {
        workspaceService.revealInFinder(urls: items.map(\.url))
    }

    // MARK: - Import & Drag/Drop

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

    func isSortedBy<T>(_ keyPath: KeyPath<FileItem, T>) -> Bool {
        guard let first = sortOrder.first else { return false }
        return first.keyPath == keyPath
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}
