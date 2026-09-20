//
//  AppRowView.swift
//  SimulatorFileManager
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import SwiftUI

struct AppRowView: View {
    let app: InstalledApp
    var isRunning: Bool = false
    let onRevealInFinder: () -> Void
    var onRevealBundleInFinder: (() -> Void)? = nil
    var onCopyBundleId: (() -> Void)? = nil
    var onCopyDataPath: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let iconData = app.iconData,
                    let nsImage = NSImage(data: iconData)
                {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quinary)
                        .overlay {
                            Image(
                                systemName: app.isSystemApp
                                    ? "gear" : "app.fill"
                            )
                            .font(.subheadline)
                        }
                        .foregroundStyle(
                            app.isSystemApp
                                ? AnyShapeStyle(.secondary)
                                : AnyShapeStyle(.tint)
                        )
                }
            }
            .frame(width: 30, height: 30)
            .clipShape(.rect(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(app.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if !app.version.isEmpty {
                        Text(verbatim: "v\(app.version)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Text(app.bundleId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if app.isSystemApp {
                Text(.appListRowSystemBadge)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(.quinary, in: .rect(cornerRadius: 3))
            }

            if isRunning {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .help(.appListRowRunningHelp)
            }
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button(.appListRowOpenDataFolder) {
                onRevealInFinder()
            }

            if app.bundleURL != nil {
                Button(.appListRowOpenAppBundle) {
                    if let onRevealBundleInFinder {
                        onRevealBundleInFinder()
                    } else if let bundleURL = app.bundleURL {
                        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
                    }
                }
            }

            Divider()

            Button(.appListRowCopyBundleId) {
                if let onCopyBundleId {
                    onCopyBundleId()
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(app.bundleId, forType: .string)
                }
            }

            Button(.appListRowCopyDataPath) {
                if let onCopyDataPath {
                    onCopyDataPath()
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        app.dataURL.path,
                        forType: .string
                    )
                }
            }
        }
    }
}
