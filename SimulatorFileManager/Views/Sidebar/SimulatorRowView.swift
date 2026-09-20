import SwiftUI

struct SimulatorRowView: View {
    let device: SimulatorDevice
    var runnerAppName: String = "Device Hub"
    let onBoot: () -> Void
    let onShutdown: () -> Void
    let onOpenSimulator: () -> Void
    let onRevealInFinder: () -> Void
    var onRevealMediaFolder: (() -> Void)? = nil
    var onAddMedia: (() -> Void)? = nil
    var onCopyUDID: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName(for: device))
                .foregroundStyle(device.state.isBooted ? Color.accentColor : Color.secondary)
                .font(.subheadline)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body)
                    .lineLimit(1)
                Text(device.runtime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if device.state.isBooted {
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)
                    .help(.simulatorStatusBooted)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            if device.state.isBooted {
                Button(.simulatorActionShutdown) {
                    onShutdown()
                }
            } else {
                Button(.simulatorActionBoot) {
                    onBoot()
                }
            }

            Button(.simulatorActionOpenInApp(runnerAppName)) {
                onOpenSimulator()
            }

            Divider()

            Button(.simulatorActionShowInFinder) {
                onRevealInFinder()
            }

            if let onRevealMediaFolder {
                Button(.simulatorActionShowMediaInFinder) {
                    onRevealMediaFolder()
                }
            }

            if device.state.isBooted, let onAddMedia {
                Button(.simulatorActionAddMedia) {
                    onAddMedia()
                }
            }

            Divider()

            Button(.simulatorActionCopyUDID) {
                if let onCopyUDID {
                    onCopyUDID()
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(device.udid, forType: .string)
                }
            }
        }
    }

    private func iconName(for device: SimulatorDevice) -> String {
        let name = device.name.lowercased()
        if name.contains("ipad") {
            return "ipad"
        } else if name.contains("watch") {
            return "applewatch"
        } else if name.contains("tv") {
            return "appletv"
        } else if name.contains("vision") {
            return "visionpro"
        }
        return "iphone"
    }
}
