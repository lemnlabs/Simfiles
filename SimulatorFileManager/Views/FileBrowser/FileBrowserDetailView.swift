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
        .alert("오류", isPresented: $viewModel.showingError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("새 폴더", isPresented: $viewModel.showingNewFolderDialog) {
            TextField("폴더 이름", text: $viewModel.newFolderName)

            Button("취소", role: .cancel) {
                viewModel.showingNewFolderDialog = false
                viewModel.newFolderName = ""
            }
            .keyboardShortcut(.cancelAction)

            Button("생성") {
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
            Button("휴지통으로 이동", role: .destructive) {
                viewModel.executeDelete()
            }
            Button("취소", role: .cancel) {
                viewModel.cancelDelete()
            }
        } message: {
            if viewModel.itemsPendingDeletion.count == 1,
                let item = viewModel.itemsPendingDeletion.first
            {
                Text("'\(item.name)' 항목이 휴지통으로 이동됩니다.")
            } else {
                Text(
                    "선택한 \(viewModel.itemsPendingDeletion.count)개 항목이 휴지통으로 이동됩니다."
                )
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
            Text("폴더가 비어 있습니다.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Finder에서 파일을 끌어다 놓거나 상단의 '파일 추가' 버튼을 눌러보세요.")
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
                Text("v\(viewModel.app.version)")
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
        // 1. 앱 실행 / 종료 토글
        if viewModel.device.state.isBooted && viewModel.app.bundleURL != nil {
            Button {
                viewModel.toggleAppExecution()
            } label: {
                Label(
                    viewModel.isAppRunning ? "앱 종료" : "앱 실행",
                    systemImage: viewModel.isAppRunning ? "stop.fill" : "play.fill"
                )
            }
            .foregroundStyle(viewModel.isAppRunning ? .orange : .green)
            .disabled(viewModel.isPerformingAppAction)
            .help(viewModel.isAppRunning ? "실행 중인 앱 종료" : "앱 실행")
        }

        // 2. 파일 추가 (Import)
        Button {
            viewModel.selectFileToImport()
        } label: {
            Label("파일 추가", systemImage: "square.and.arrow.down")
        }
        .help("Mac에서 파일을 선택하여 현재 폴더로 가져옵니다.")

        // 3. 새 폴더
        Button {
            viewModel.showingNewFolderDialog = true
        } label: {
            Label("새로운 폴더", systemImage: "folder.badge.plus")
        }
        .help("새 폴더 생성")

        // 4. 정렬 메뉴
        Menu {
            Section("정렬 기준") {
                Button {
                    viewModel.sortOrder = [KeyPathComparator(\.name, order: .forward)]
                } label: {
                    HStack {
                        Text("이름")
                        if viewModel.isSortedBy(\.name) { Image(systemName: "checkmark") }
                    }
                }
                Button {
                    viewModel.sortOrder = [KeyPathComparator(\.typeDescription, order: .forward)]
                } label: {
                    HStack {
                        Text("종류")
                        if viewModel.isSortedBy(\.typeDescription) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button {
                    viewModel.sortOrder = [KeyPathComparator(\.size, order: .forward)]
                } label: {
                    HStack {
                        Text("크기")
                        if viewModel.isSortedBy(\.size) { Image(systemName: "checkmark") }
                    }
                }
                Button {
                    viewModel.sortOrder = [KeyPathComparator(\.sortableDate, order: .reverse)]
                } label: {
                    HStack {
                        Text("수정일")
                        if viewModel.isSortedBy(\.sortableDate) { Image(systemName: "checkmark") }
                    }
                }
            }

            Divider()

            Toggle("폴더 항상 위에 표시", isOn: $viewModel.foldersAlwaysOnTop)
        } label: {
            Label("정렬", systemImage: "arrow.up.arrow.down")
        }
        .help("정렬 옵션")

        // 5. 더보기 / 동작 (Action Menu)
        Menu {
            Button("Finder에서 열기") {
                viewModel.openInFinder()
            }

            Button("터미널에서 열기") {
                viewModel.openInTerminal()
            }

            Button("현재 폴더 경로 복사") {
                viewModel.copyCurrentPath()
            }

            if !viewModel.clipboardService.isEmpty {
                Divider()
                Button(
                    viewModel.clipboardService.isCut
                        ? "잘라낸 항목 이동 (\(viewModel.clipboardService.count)개)"
                        : "복사한 항목 붙여넣기 (\(viewModel.clipboardService.count)개)"
                ) {
                    viewModel.pasteClipboard(to: viewModel.currentPathURL)
                }
            }

            if !viewModel.selectedFiles.isEmpty {
                Divider()
                Menu("선택 항목 이동...") {
                    FileBrowserMoveMenu(viewModel: viewModel, items: viewModel.selectedFiles)
                }
                Button("선택 항목 복사") {
                    viewModel.copyItems(viewModel.selectedFiles)
                }
                Button("선택 항목 잘라내기") {
                    viewModel.cutItems(viewModel.selectedFiles)
                }
                Button("선택 항목 경로 복사") {
                    viewModel.copyPaths(for: viewModel.selectedFiles)
                }
            }

            Divider()

            Button("새로고침") {
                viewModel.reloadFiles()
            }
        } label: {
            Label("동작", systemImage: "ellipsis.circle")
        }
        .help("추가 동작")

        // 6. 삭제 (선택 항목이 있을 때 활성화)
        Button(role: .destructive) {
            viewModel.confirmDelete(items: viewModel.selectedFiles)
        } label: {
            Label("삭제", systemImage: "trash")
        }
        .disabled(viewModel.selectedItemIDs.isEmpty)
        .help(viewModel.selectedItemIDs.isEmpty ? "삭제할 항목을 선택하세요" : "선택한 항목 삭제 (⌘⌫)")
    }
}
