import AppKit
import SwiftUI

struct FileBrowserPathBarView: View {
    @Bindable var viewModel: FileBrowserViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // 1. Finder 스타일 뒤로가기 / 앞으로가기 내비게이션 버튼
                HStack(spacing: 2) {
                    Button(action: { viewModel.goBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                            .frame(width: 22, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(NavigationHistoryButtonStyle())
                    .disabled(!viewModel.canGoBack)
                    .help("뒤로 이동 (⌘[)")
                    .contextMenu {
                        if !viewModel.backStack.isEmpty {
                            ForEach(
                                Array(viewModel.backStack.enumerated().reversed()), id: \.offset
                            ) {
                                index, url in
                                Button {
                                    viewModel.navigateBack(to: index)
                                } label: {
                                    Label(
                                        viewModel.displayName(for: url),
                                        systemImage: viewModel.iconName(for: url))
                                }
                            }
                        }
                    }

                    Button(action: { viewModel.goForward() }) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .frame(width: 22, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(NavigationHistoryButtonStyle())
                    .disabled(!viewModel.canGoForward)
                    .help("앞으로 이동 (⌘])")
                    .contextMenu {
                        if !viewModel.forwardStack.isEmpty {
                            ForEach(
                                Array(viewModel.forwardStack.enumerated().reversed()), id: \.offset
                            ) {
                                index, url in
                                Button {
                                    viewModel.navigateForward(to: index)
                                } label: {
                                    Label(
                                        viewModel.displayName(for: url),
                                        systemImage: viewModel.iconName(for: url))
                                }
                            }
                        }
                    }
                }

                Divider()
                    .frame(height: 12)

                // 2. Finder 스타일 브레드크럼 (Breadcrumb / Path Control)
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(Array(viewModel.pathBreadcrumbs.enumerated()), id: \.element.id) {
                            index, crumb in
                            let isLast = index == viewModel.pathBreadcrumbs.count - 1

                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }

                            Button(action: {
                                viewModel.navigateToURL(crumb.url)
                            }) {
                                HStack(spacing: 4) {
                                    Image(
                                        systemName: index == 0
                                            ? iconForSandbox(crumb.title) : "folder.fill"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        isLast ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))

                                    Text(crumb.title)
                                        .font(.callout.weight(isLast ? .semibold : .regular))
                                        .foregroundStyle(isLast ? .primary : .secondary)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Finder에서 열기") {
                                    NSWorkspace.shared.activateFileViewerSelecting([crumb.url])
                                }
                                Button("경로 복사") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(crumb.url.path, forType: .string)
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(height: 32)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()
        }
    }

    private func iconForSandbox(_ name: String) -> String {
        switch name {
        case SandboxDirectory.documents.rawValue: return "doc.on.doc.fill"
        case SandboxDirectory.library.rawValue: return "books.vertical.fill"
        case SandboxDirectory.tmp.rawValue: return "clock.arrow.circlepath"
        default: return "folder.fill"
        }
    }
}

private struct NavigationHistoryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundStyle(for: configuration))
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        isEnabled && (configuration.isPressed || isHovered)
                            ? Color.primary.opacity(configuration.isPressed ? 0.15 : 0.08)
                            : Color.clear
                    )
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private func foregroundStyle(for configuration: Configuration) -> AnyShapeStyle {
        if !isEnabled {
            return AnyShapeStyle(.quaternary)
        }
        if configuration.isPressed {
            return AnyShapeStyle(.primary)
        }
        return AnyShapeStyle(.secondary)
    }
}
