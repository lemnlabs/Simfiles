//
//  AppListView.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

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
                    .appListPlaceholderSelectSimulator,
                    systemImage: "ipad.landscape.and.iphone"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isLoading {
                ProgressView {
                    Text(.appListStatusSearching)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredApps.isEmpty {
                ContentUnavailableView {
                    Label(
                        viewModel.filterScope == .userOnly
                            ? .appListEmptyNoUserApps : .appListEmptyNoApps,
                        systemImage: "app.dashed"
                    )
                } actions: {
                    if viewModel.filterScope == .userOnly {
                        Button(.appListActionShowAllApps) {
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
            Picker(.commonFilter, selection: $viewModel.filterScope) {
                ForEach(AppFilterScope.allCases) { scope in
                    Text(scope.title).tag(scope)
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
                        Button(.simulatorActionShowMediaInFinder) {
                            viewModel.revealMediaFolderInFinder()
                        }
                        if device.state.isBooted {
                            Button(.simulatorActionAddMedia) {
                                viewModel.addMediaToCurrentDevice()
                            }
                        }
                    } label: {
                        Label(.appListMediaMenuLabel, systemImage: "photo.on.rectangle.angled")
                    }
                    .help(.appListMediaHelp)
                }

                Button(.commonRefresh, systemImage: "arrow.clockwise") {
                    reloadApps()
                }
                .help(.appListActionRefreshHelp)
            }
        }
        .searchable(
            text: $viewModel.searchText,
            prompt: Text(.appListSearchPrompt)
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
                // Preserve existing selection
            } else {
                selectedApp = defaultApp
            }
        }
    }
}
