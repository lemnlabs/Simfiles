import SwiftUI

struct AppView: View {
    @State private var viewModel = AppViewModel()
    @State private var simulatorManager = SimulatorManager()
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                simulatorManager: simulatorManager,
                selectedDevice: $viewModel.selectedDevice,
                columnVisibility: columnVisibility
            )
        } content: {
            AppListView(
                device: viewModel.selectedDevice,
                selectedApp: $viewModel.selectedApp,
                simulatorManager: simulatorManager
            )
        } detail: {
            if let device = viewModel.selectedDevice,
                let app = viewModel.selectedApp
            {
                FileBrowserDetailView(
                    device: device,
                    app: app,
                    simulatorManager: simulatorManager
                )
                .id("\(device.udid)-\(app.bundleId)")
            } else {
                noSelectionPlaceholderView
            }
        }
        .navigationTitle(viewModel.navigationTitleText)
        .task {
            await simulatorManager.fetchDevices()
            viewModel.selectDefaultDeviceIfNeeded(
                devices: simulatorManager.devices
            )
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .didReceiveExternalFiles)
        ) { notification in
            guard let urls = notification.userInfo?["urls"] as? [URL],
                !urls.isEmpty
            else { return }
            viewModel.handleIncomingExternalFiles(urls)
        }
        .alert(item: $viewModel.activeAlert)
    }

    private var noSelectionPlaceholderView: some View {
        ContentUnavailableView(
            "선택된 앱이 없습니다",
            systemImage: "folder.badge.questionmark",
            description: Text("왼쪽 목록에서 시뮬레이터와 앱을 선택하면\n내부 파일 목록을 확인하고 파일을 넣을 수 있습니다.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AppView()
        .frame(minWidth: 1920 / 2, minHeight: 1080 / 2)
}
