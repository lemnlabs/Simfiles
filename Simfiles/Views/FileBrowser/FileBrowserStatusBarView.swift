//
//  FileBrowserStatusBarView.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import SwiftUI

struct FileBrowserStatusBarView: View {
    let totalCount: Int
    let selectedCount: Int
    let selectedTotalSize: Int64
    let formattedSelectedSize: String

    var body: some View {
        HStack(spacing: 8) {
            if selectedCount == 0 {
                Text(.fileBrowserStatusTotalItems(totalCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if selectedTotalSize > 0 {
                Text(
                    .fileBrowserStatusSelectedItemsWithSize(
                        selectedCount,
                        totalCount,
                        formattedSelectedSize
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            } else {
                Text(
                    .fileBrowserStatusSelectedItems(
                        selectedCount,
                        totalCount
                    )
                )
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
