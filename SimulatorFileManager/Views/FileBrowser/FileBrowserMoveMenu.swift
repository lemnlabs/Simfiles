//
//  FileBrowserMoveMenu.swift
//  SimulatorFileManager
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import SwiftUI

struct FileBrowserMoveMenu: View {
    let viewModel: FileBrowserViewModel
    let items: [FileItem]

    var body: some View {
        if !viewModel.isAtRootDirectory {
            Button(.fileBrowserMoveParentFolder) {
                viewModel.moveItems(
                    items,
                    to: viewModel.currentPathURL.deletingLastPathComponent()
                )
            }
            Divider()
        }

        Button(.fileBrowserMoveDocuments) {
            viewModel.moveItems(items, to: viewModel.app.documentsURL)
        }
        Button(.fileBrowserMoveLibrary) {
            viewModel.moveItems(items, to: viewModel.app.libraryURL)
        }
        Button(.fileBrowserMoveTmp) {
            viewModel.moveItems(items, to: viewModel.app.tmpURL)
        }

        let itemPaths = Set(items.map(\.url.standardizedFileURL.path))
        let availableSubfolders = viewModel.fileItems.filter {
            $0.isDirectory && !itemPaths.contains($0.url.standardizedFileURL.path)
        }
        if !availableSubfolders.isEmpty {
            Divider()
            Menu(.fileBrowserMoveSubfolders) {
                ForEach(availableSubfolders) { subfolder in
                    Button(.fileBrowserMoveToSubfolder(subfolder.name)) {
                        viewModel.moveItems(items, to: subfolder.url)
                    }
                }
            }
        }

        Divider()

        Button(.fileBrowserMoveChooseFolder) {
            viewModel.promptMove(items: items)
        }
    }
}
