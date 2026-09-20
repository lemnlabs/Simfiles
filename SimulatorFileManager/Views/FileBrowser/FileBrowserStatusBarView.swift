import SwiftUI

struct FileBrowserStatusBarView: View {
    let totalCount: Int
    let selectedCount: Int
    let selectedTotalSize: Int64
    let formattedSelectedSize: String

    var body: some View {
        HStack(spacing: 8) {
            if selectedCount == 0 {
                Text("\(totalCount)개 항목")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                let sizeText: Text = Text(
                    selectedTotalSize > 0 ? " (\(formattedSelectedSize))" : ""
                )
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

                Text("\(totalCount)개 항목 중 \(selectedCount)개 선택됨\(sizeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
