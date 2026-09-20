import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel
    @Binding var selectedDevice: SimulatorDevice?
    var columnVisibility: NavigationSplitViewVisibility = .all

    init(
        viewModel: SidebarViewModel,
        selectedDevice: Binding<SimulatorDevice?>,
        columnVisibility: NavigationSplitViewVisibility = .all
    ) {
        self.viewModel = viewModel
        self._selectedDevice = selectedDevice
        self.columnVisibility = columnVisibility
    }

    init(
        simulatorManager: SimulatorManager,
        selectedDevice: Binding<SimulatorDevice?>,
        columnVisibility: NavigationSplitViewVisibility = .all
    ) {
        self.viewModel = SidebarViewModel(simulatorManager: simulatorManager)
        self._selectedDevice = selectedDevice
        self.columnVisibility = columnVisibility
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.devices.isEmpty {
                ProgressView {
                    Text(.sidebarSimulatorSearching)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredDevices.isEmpty {
                ContentUnavailableView(
                    .sidebarSimulatorEmpty,
                    systemImage: "iphone.slash"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedDevice) {
                    ForEach(viewModel.sortedRuntimes, id: \.self) { runtime in
                        Section(
                            header: Text(runtime)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        ) {
                            ForEach(viewModel.groupedDevices[runtime] ?? []) {
                                device in
                                SimulatorRowView(
                                    device: device,
                                    runnerAppName: viewModel.runnerAppName,
                                    onBoot: {
                                        Task {
                                            await viewModel.bootDevice(device)
                                        }
                                    },
                                    onShutdown: {
                                        Task {
                                            await viewModel.shutdownDevice(
                                                device
                                            )
                                        }
                                    },
                                    onOpenSimulator: {
                                        viewModel.openSimulatorApp(for: device)
                                    },
                                    onRevealInFinder: {
                                        viewModel.revealInFinder(device: device)
                                    },
                                    onRevealMediaFolder: {
                                        viewModel.revealMediaFolder(for: device)
                                    },
                                    onAddMedia: {
                                        viewModel.addMedia(for: device)
                                    },
                                    onCopyUDID: {
                                        viewModel.copyUDID(for: device)
                                    }
                                )
                                .tag(device)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .sidebar,
            prompt: Text(.sidebarSimulatorSearchPrompt)
        )
        .toolbar {
            if columnVisibility == .all {
                ToolbarItemGroup {
                    Button(
                        .commonRefresh,
                        systemImage: "arrow.clockwise"
                    ) {
                        Task {
                            await viewModel.refreshDevices()
                        }
                    }
                    .help(.commonRefresh)

                    Menu(.commonFilter, systemImage: "line.3.horizontal.decrease") {
                        Toggle(.sidebarFilterBootedOnly, isOn: $viewModel.showOnlyBooted)
                    }
                    .menuIndicator(.hidden)
                    .help(.commonFilter)
                }
            }
        }
    }
}
