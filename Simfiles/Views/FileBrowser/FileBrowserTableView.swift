//
//  FileBrowserTableView.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

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
            TableColumn(.fileBrowserTableColumnName, value: \.name) { item in
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

            TableColumn(.fileBrowserTableColumnKind, value: \.typeDescription) { item in
                Text(item.typeDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 110, max: 150)

            TableColumn(.fileBrowserTableColumnSize, value: \.size) { item in
                Text(item.formattedSize)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80, max: 100)

            TableColumn(.fileBrowserTableColumnDateModified, value: \.sortableDate) { item in
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
            Button(.commonOpen) {
                viewModel.handleDoubleClick(on: single)
            }
            if !single.isDirectory {
                Button(.fileBrowserActionQuickLook) {
                    viewModel.previewURL = single.url
                }
            }
        }

        Button(.fileBrowserActionShowInFinderCount(count)) {
            viewModel.revealInFinder(items: targets)
        }

        if count == 1, let single = targets.first, single.isDirectory {
            Button(.fileBrowserActionOpenInTerminal) {
                let terminalURL = URL(
                    fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
                NSWorkspace.shared.open(
                    [single.url], withApplicationAt: terminalURL,
                    configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            }
        }

        Divider()

        Button(.fileBrowserActionCopyPathCount(count)) {
            viewModel.copyPaths(for: targets)
        }

        Button(.fileBrowserActionCopyItemCount(count)) {
            viewModel.copyItems(targets)
        }

        Button(.fileBrowserActionCutItemCount(count)) {
            viewModel.cutItems(targets)
        }

        if !viewModel.clipboardService.isEmpty {
            Button(.fileBrowserActionPasteHereCount(viewModel.clipboardService.count)) {
                viewModel.pasteClipboard(
                    to: item.isDirectory ? item.url : viewModel.currentPathURL
                )
            }
        }

        Divider()

        Menu(.fileBrowserActionMoveMenuCount(count)) {
            FileBrowserMoveMenu(viewModel: viewModel, items: targets)
        }

        Divider()

        Button(
            .fileBrowserActionMoveToTrashCount(count),
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
