import SwiftUI

struct AppListView: View {
    let device: SimulatorDevice?
    @Binding var selectedApp: InstalledApp?

    @State private var viewModel: AppListViewModel

    init(
        device: SimulatorDevice?,
        selectedApp: Binding<InstalledApp?>,
        simulatorManager: SimulatorManager? = nil
    ) {
        self.device = device
        self._selectedApp = selectedApp
        _viewModel = State(
            initialValue: AppListViewModel(
                simulatorManager: simulatorManager
            )
        )
    }

    var body: some View {
        Group {
            if device == nil {
                ContentUnavailableView(
                    "시뮬레이터를 선택해 주세요.",
                    systemImage: "ipad.landscape.and.iphone"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isLoading {
                ProgressView {
                    Text("설치된 앱 검색 중...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredApps.isEmpty {
                ContentUnavailableView {
                    Label(
                        viewModel.filterScope == .userOnly
                            ? "설치된 사용자 앱이 없습니다." : "앱이 없습니다.",
                        systemImage: "app.dashed"
                    )
                } actions: {
                    if viewModel.filterScope == .userOnly {
                        Button("전체 앱 표시하기") {
                            viewModel.filterScope = .all
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedApp) {
                    ForEach(viewModel.filteredApps) { app in
                        AppRowView(
                            app: app,
                            isRunning: viewModel.isAppRunning(
                                bundleId: app.bundleId
                            ),
                            onRevealInFinder: {
                                viewModel.revealDataFolderInFinder(for: app)
                            },
                            onRevealBundleInFinder: {
                                viewModel.revealBundleInFinder(for: app)
                            },
                            onCopyBundleId: {
                                viewModel.copyBundleId(for: app)
                            },
                            onCopyDataPath: {
                                viewModel.copyDataFolderPath(for: app)
                            }
                        )
                        .tag(app)
                    }
                }
                .listStyle(.inset)
            }
        }
        .safeAreaInset(edge: .top) {
            Picker("필터", selection: $viewModel.filterScope) {
                ForEach(AppFilterScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .toolbar {
            ToolbarItemGroup {
                if let device {
                    Menu {
                        Button("Finder에서 미디어 폴더 열기") {
                            viewModel.revealMediaFolderInFinder()
                        }
                        if device.state.isBooted {
                            Button("사진/동영상 추가...") {
                                viewModel.addMediaToCurrentDevice()
                            }
                        }
                    } label: {
                        Label("기기 미디어", systemImage: "photo.on.rectangle.angled")
                    }
                    .help("시뮬레이터 사진 및 미디어 도구")
                }

                Button("새로고침", systemImage: "arrow.clockwise") {
                    reloadApps()
                }
                .help("앱 목록 새로고침")
            }
        }
        .searchable(
            text: $viewModel.searchText,
            prompt: "앱 이름 또는 Bundle ID 검색"
        )
        .frame(minWidth: 240, idealWidth: 280)
        .onChange(of: device, initial: true) { _, newDevice in
            selectedApp = nil
            reloadApps(device: newDevice)
        }
    }

    private func reloadApps(device: SimulatorDevice? = nil) {
        let targetDevice = device ?? self.device
        viewModel.loadApps(for: targetDevice) { defaultApp in
            if let currentSelected = selectedApp,
                viewModel.installedApps.contains(currentSelected)
            {
                // 기존 선택 유지
            } else {
                selectedApp = defaultApp
            }
        }
    }
}
