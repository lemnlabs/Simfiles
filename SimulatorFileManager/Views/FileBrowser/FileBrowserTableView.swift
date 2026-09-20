import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserTableView: View {
    @Bindable var viewModel: FileBrowserViewModel

    var body: some View {
        Table(
            viewModel.sortedFileItems,
            selection: $viewModel.selectedItemIDs,
            sortOrder: $viewModel.sortOrder
        ) {
            TableColumn("이름", value: \.name) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.systemImageName)
                        .foregroundStyle(item.iconColor)
                        .font(.body)
                        .frame(width: 18)
                    Text(item.name)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .draggable(item.url)
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        viewModel.handleDoubleClick(on: item)
                    }
                )
                .modifier(
                    FolderDropModifier(isDirectory: item.isDirectory) { providers in
                        viewModel.handleDrop(providers: providers, targetDirectory: item.url)
                    }
                )
                .contextMenu {
                    contextMenuContent(for: item)
                }
            }
            .width(min: 200, ideal: 300)

            TableColumn("종류", value: \.typeDescription) { item in
                Text(item.typeDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 110, max: 150)

            TableColumn("크기", value: \.size) { item in
                Text(item.formattedSize)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80, max: 100)

            TableColumn("수정일", value: \.sortableDate) { item in
                Text(item.formattedDate)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 150)
        }
    }

    @ViewBuilder
    private func contextMenuContent(for item: FileItem) -> some View {
        let targets = viewModel.itemsToActOn(for: item)
        let count = targets.count

        if count == 1, let single = targets.first {
            Button("열기") {
                viewModel.handleDoubleClick(on: single)
            }
            if !single.isDirectory {
                Button("미리보기 (Quick Look)") {
                    viewModel.previewURL = single.url
                }
            }
        }

        Button(count == 1 ? "Finder에서 보기" : "\(count)개 항목 Finder에서 보기") {
            viewModel.revealInFinder(items: targets)
        }

        if count == 1, let single = targets.first, single.isDirectory {
            Button("터미널에서 열기") {
                let terminalURL = URL(
                    fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
                NSWorkspace.shared.open(
                    [single.url], withApplicationAt: terminalURL,
                    configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            }
        }

        Divider()

        Button(count == 1 ? "경로 복사" : "\(count)개 항목 경로 복사") {
            viewModel.copyPaths(for: targets)
        }

        Button(count == 1 ? "복사" : "\(count)개 항목 복사") {
            viewModel.copyItems(targets)
        }

        Button(count == 1 ? "잘라내기 (이동)" : "\(count)개 항목 잘라내기 (이동)") {
            viewModel.cutItems(targets)
        }

        if !viewModel.clipboardService.isEmpty {
            Button("여기에 붙여넣기 (\(viewModel.clipboardService.count)개)") {
                viewModel.pasteClipboard(
                    to: item.isDirectory ? item.url : viewModel.currentPathURL
                )
            }
        }

        Divider()

        Menu(count == 1 ? "이동..." : "\(count)개 항목 이동...") {
            FileBrowserMoveMenu(viewModel: viewModel, items: targets)
        }

        Divider()

        Button(
            count == 1 ? "삭제 (휴지통으로 이동)" : "\(count)개 항목 삭제 (휴지통으로 이동)",
            role: .destructive
        ) {
            viewModel.confirmDelete(items: targets)
        }
    }
}

private struct FolderDropModifier: ViewModifier {
    let isDirectory: Bool
    let onDrop: ([NSItemProvider]) -> Bool

    func body(content: Content) -> some View {
        if isDirectory {
            content.onDrop(of: [.fileURL], isTargeted: nil) { providers in
                onDrop(providers)
            }
        } else {
            content
        }
    }
}
