import SwiftUI

struct FileBrowserMoveMenu: View {
    let viewModel: FileBrowserViewModel
    let items: [FileItem]

    var body: some View {
        if !viewModel.isAtRootDirectory {
            Button("상위 폴더로 이동") {
                viewModel.moveItems(
                    items,
                    to: viewModel.currentPathURL.deletingLastPathComponent()
                )
            }
            Divider()
        }

        Button("Documents로 이동") {
            viewModel.moveItems(items, to: viewModel.app.documentsURL)
        }
        Button("Library로 이동") {
            viewModel.moveItems(items, to: viewModel.app.libraryURL)
        }
        Button("tmp로 이동") {
            viewModel.moveItems(items, to: viewModel.app.tmpURL)
        }

        let itemPaths = Set(items.map(\.url.standardizedFileURL.path))
        let availableSubfolders = viewModel.fileItems.filter {
            $0.isDirectory && !itemPaths.contains($0.url.standardizedFileURL.path)
        }
        if !availableSubfolders.isEmpty {
            Divider()
            Menu("현재 폴더 내 서브폴더") {
                ForEach(availableSubfolders) { subfolder in
                    Button("'\(subfolder.name)' 폴더로 이동") {
                        viewModel.moveItems(items, to: subfolder.url)
                    }
                }
            }
        }

        Divider()

        Button("폴더 선택하여 이동...") {
            viewModel.promptMove(items: items)
        }
    }
}
