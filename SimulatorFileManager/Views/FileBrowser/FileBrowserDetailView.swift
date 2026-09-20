import AppKit
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserDetailView: View {
    @State private var viewModel: FileBrowserViewModel

    init(
        device: SimulatorDevice,
        app: InstalledApp,
        fileService: FileManagerServiceProtocol = FileManagerService(),
        simulatorManager: SimulatorManager? = nil
    ) {
        self.viewModel = FileBrowserViewModel(
            device: device,
            app: app,
            fileService: fileService,
            simulatorManager: simulatorManager
        )
    }

    var body: some View {
        ZStack {
            if viewModel.fileItems.isEmpty {
                emptyStateView
            } else {
                FileBrowserTableView(viewModel: viewModel)
            }

            if viewModel.isTargetedForDrop {
                FileBrowserDropOverlay()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top) {
            FileBrowserPathBarView(viewModel: viewModel)
        }
        .safeAreaInset(edge: .bottom) {
            FileBrowserStatusBarView(
                totalCount: viewModel.fileItems.count,
                selectedCount: viewModel.selectedItemIDs.count,
                selectedTotalSize: viewModel.selectedTotalSize,
                formattedSelectedSize: viewModel.formattedSelectedSize
            )
            .background(.regularMaterial)
        }
        .toolbar {
            if #available(macOS 26.0, *) {
                ToolbarItem(placement: .principal) {
                    appHeaderToolbarItem
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .principal) {
                    appHeaderToolbarItem
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                toolbarActionButtons
            }
        }
        .quickLookPreview($viewModel.previewURL)
        .onKeyPress(.space) {
            if !viewModel.selectedFiles.isEmpty {
                viewModel.toggleQuickLook()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(phases: .down) { press in
            if press.modifiers.contains(.command) {
                if press.key == "[" && viewModel.canGoBack {
                    viewModel.goBack()
                    return .handled
                }
                if press.key == "]" && viewModel.canGoForward {
                    viewModel.goForward()
                    return .handled
                }
                if press.key == .upArrow && !viewModel.isAtRootDirectory {
                    viewModel.navigateToParent()
                    return .handled
                }
            }
            return .ignored
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $viewModel.isTargetedForDrop) {
            providers in
            viewModel.handleDrop(providers: providers)
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
        .onChange(of: viewModel.app) { _, newApp in
            viewModel.switchDirectory(to: .root)
            viewModel.clearHistory()
        }
        .alert(Text(.commonError), isPresented: $viewModel.showingError) {
            Button(.commonOk, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert(Text(.fileBrowserNewFolderTitle), isPresented: $viewModel.showingNewFolderDialog) {
            TextField(text: $viewModel.newFolderName) {
                Text(.fileBrowserNewFolderNamePlaceholder)
            }

            Button(.commonCancel, role: .cancel) {
                viewModel.showingNewFolderDialog = false
                viewModel.newFolderName = ""
            }
            .keyboardShortcut(.cancelAction)

            Button(.commonCreate) {
                viewModel.createFolder()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(
                viewModel.newFolderName.trimmingCharacters(in: .whitespaces)
                    .isEmpty
            )
        }
        .onDeleteCommand {
            if !viewModel.selectedFiles.isEmpty {
                viewModel.confirmDelete(items: viewModel.selectedFiles)
            }
        }
        .confirmationDialog(
            viewModel.deleteConfirmationTitle,
            isPresented: $viewModel.showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(.fileBrowserDeleteConfirmAction, role: .destructive) {
                viewModel.executeDelete()
            }
            Button(.commonCancel, role: .cancel) {
                viewModel.cancelDelete()
            }
        } message: {
            if viewModel.itemsPendingDeletion.count == 1,
                let item = viewModel.itemsPendingDeletion.first
            {
                Text(.fileBrowserDeleteMessageSingle(item.name))
            } else {
                Text(.fileBrowserDeleteMessageMultiple(viewModel.itemsPendingDeletion.count))
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.secondary)
            Text(.fileBrowserEmptyTitle)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(.fileBrowserEmptyDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}

extension FileBrowserDetailView {
    @ViewBuilder
    private var appHeaderToolbarItem: some View {
        HStack(spacing: 8) {
            if let iconData = viewModel.app.iconData,
                let nsImage = NSImage(data: iconData)
            {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .clipShape(.rect(cornerRadius: 4))
            } else {
                Image(systemName: viewModel.app.isSystemApp ? "gear" : "app.fill")
                    .foregroundStyle(.tint)
                    .font(.subheadline)
            }

            Text(viewModel.app.displayName)
                .font(.headline)
                .lineLimit(1)

            if !viewModel.app.version.isEmpty {
                Text(verbatim: "v\(viewModel.app.version)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.quinary, in: .rect(cornerRadius: 3))
            }
        }
    }

    @ViewBuilder
    private var toolbarActionButtons: some View {
        // 1. App execution toggle
        if viewModel.device.state.isBooted && viewModel.app.bundleURL != nil {
            Button {
                viewModel.toggleAppExecution()
            } label: {
                Label(
                    viewModel.isAppRunning
                        ? .fileBrowserToolbarTerminateApp : .fileBrowserToolbarLaunchApp,
                    systemImage: viewModel.isAppRunning ? "stop.fill" : "play.fill"
                )
            }
            .foregroundStyle(viewModel.isAppRunning ? .orange : .green)
            .disabled(viewModel.isPerformingAppAction)
            .help(
                viewModel.isAppRunning
                    ? .fileBrowserToolbarTerminateAppHelp : .fileBrowserToolbarLaunchApp)
        }

        // 2. Add Files (Import)
        Button {
            viewModel.selectFileToImport()
        } label: {
            Label(.fileBrowserToolbarAddFiles, systemImage: "square.and.arrow.down")
        }
        .help(.fileBrowserToolbarAddFilesHelp)

        // 3. New Folder
        Button {
            viewModel.showingNewFolderDialog = true
        } label: {
            Label(.fileBrowserToolbarNewFolder, systemImage: "folder.badge.plus")
        }
        .help(.fileBrowserToolbarNewFolderHelp)

        // 4. Sort Menu
        Menu {
            Section(.fileBrowserSortSectionTitle) {
                Button {
                    viewModel.sortOrder = [KeyPathComparator(\.name, order: .forward)]
                } label: {
                    HStack {
                        Text(.fileBrowserSortName)
                        if viewModel.isSortedBy(\.name) { Image(systemName: "checkmark") }
                    }
                }
                Button {
                    viewModel.sortOrder = [KeyPathComparator(\.typeDescription, order: .forward)]
                } label: {
                    HStack {
                        Text(.fileBrowserSortKind)
                        if viewModel.isSortedBy(\.typeDescription) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button {
                    viewModel.sortOrder = [KeyPathComparator(\.size, order: .forward)]
                } label: {
                    HStack {
                        Text(.fileBrowserSortSize)
                        if viewModel.isSortedBy(\.size) { Image(systemName: "checkmark") }
                    }
                }
                Button {
                    viewModel.sortOrder = [KeyPathComparator(\.sortableDate, order: .reverse)]
                } label: {
                    HStack {
                        Text(.fileBrowserSortDateModified)
                        if viewModel.isSortedBy(\.sortableDate) { Image(systemName: "checkmark") }
                    }
                }
            }

            Divider()

            Toggle(.fileBrowserSortKeepFoldersOnTop, isOn: $viewModel.foldersAlwaysOnTop)
        } label: {
            Label(.fileBrowserSortButtonLabel, systemImage: "arrow.up.arrow.down")
        }
        .help(.fileBrowserSortButtonHelp)

        // 5. Action Menu
        Menu {
            Button(.fileBrowserActionOpenInFinder) {
                viewModel.openInFinder()
            }

            Button(.fileBrowserActionOpenInTerminal) {
                viewModel.openInTerminal()
            }

            Button(.fileBrowserActionCopyCurrentPath) {
                viewModel.copyCurrentPath()
            }

            if !viewModel.clipboardService.isEmpty {
                Divider()
                Button(
                    viewModel.clipboardService.isCut
                        ? .fileBrowserActionMoveCutCount(viewModel.clipboardService.count)
                        : .fileBrowserActionPasteCopiedCount(viewModel.clipboardService.count)
                ) {
                    viewModel.pasteClipboard(to: viewModel.currentPathURL)
                }
            }

            if !viewModel.selectedFiles.isEmpty {
                Divider()
                Menu(.fileBrowserActionMoveSelection) {
                    FileBrowserMoveMenu(viewModel: viewModel, items: viewModel.selectedFiles)
                }
                Button(.fileBrowserActionCopySelection) {
                    viewModel.copyItems(viewModel.selectedFiles)
                }
                Button(.fileBrowserActionCutSelection) {
                    viewModel.cutItems(viewModel.selectedFiles)
                }
                Button(.fileBrowserActionCopySelectionPaths) {
                    viewModel.copyPaths(for: viewModel.selectedFiles)
                }
            }

            Divider()

            Button(.commonRefresh) {
                viewModel.reloadFiles()
            }
        } label: {
            Label(.fileBrowserToolbarActionLabel, systemImage: "ellipsis.circle")
        }
        .help(.fileBrowserToolbarActionHelp)

        // 6. Delete
        Button(role: .destructive) {
            viewModel.confirmDelete(items: viewModel.selectedFiles)
        } label: {
            Label(.fileBrowserToolbarDeleteLabel, systemImage: "trash")
        }
        .disabled(viewModel.selectedItemIDs.isEmpty)
        .help(
            viewModel.selectedItemIDs.isEmpty
                ? .fileBrowserToolbarDeleteEmptyHelp
                : .fileBrowserToolbarDeleteShortcutHelp
        )
    }
}
