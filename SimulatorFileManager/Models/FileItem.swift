import Foundation
import SwiftUI
import UniformTypeIdentifiers

nonisolated struct FileItem: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date?
    let contentType: UTType?

    init(
        url: URL,
        isDirectory: Bool,
        size: Int64,
        modificationDate: Date?,
        contentType: UTType? = nil
    ) {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.size = size
        self.modificationDate = modificationDate

        if isDirectory {
            self.contentType = .folder
        } else if let contentType {
            self.contentType = contentType
        } else if let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
            let type = resourceValues.contentType
        {
            self.contentType = type
        } else {
            self.contentType = UTType(filenameExtension: url.pathExtension)
        }
    }

    var formattedSize: String {
        if isDirectory {
            return "--"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        guard let modificationDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }

    var sortableDate: TimeInterval {
        modificationDate?.timeIntervalSince1970 ?? 0
    }

    var typeDescription: String {
        if isDirectory {
            return String(localized: .fileBrowserTypeFolder)
        }
        return contentType?.localizedDescription ?? String(localized: .fileBrowserTypeFile)
    }

    var systemImageName: String {
        if isDirectory {
            return "folder.fill"
        }

        guard let contentType else {
            return "doc.fill"
        }

        if contentType.conforms(to: .image) {
            return "photo.fill"
        } else if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
            return "film.fill"
        } else if contentType.conforms(to: .audio) {
            return "music.note"
        } else if contentType.conforms(to: .json) || contentType.conforms(to: .propertyList)
            || contentType.conforms(to: .xml)
        {
            return "curlybraces"
        } else if contentType.conforms(to: .database) {
            return "cylinder.split.1x2.fill"
        } else if contentType.conforms(to: .sourceCode) {
            return "chevron.left.forwardslash.chevron.right"
        } else if contentType.conforms(to: .pdf) {
            return "doc.richtext.fill"
        } else if contentType.conforms(to: .archive) {
            return "doc.zipper"
        } else if contentType.conforms(to: .plainText) {
            return "doc.text.fill"
        } else {
            return "doc.fill"
        }
    }

    var iconColor: AnyShapeStyle {
        if isDirectory {
            return AnyShapeStyle(.tint)
        }

        guard let contentType else {
            return AnyShapeStyle(.secondary)
        }

        if contentType.conforms(to: .image) {
            return AnyShapeStyle(.purple)
        } else if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
            return AnyShapeStyle(.pink)
        } else if contentType.conforms(to: .audio) {
            return AnyShapeStyle(.orange)
        } else if contentType.conforms(to: .json) || contentType.conforms(to: .propertyList)
            || contentType.conforms(to: .xml)
        {
            return AnyShapeStyle(.green)
        } else if contentType.conforms(to: .database) {
            return AnyShapeStyle(.indigo)
        } else if contentType.conforms(to: .sourceCode) {
            return AnyShapeStyle(.cyan)
        } else if contentType.conforms(to: .archive) {
            return AnyShapeStyle(.brown)
        } else {
            return AnyShapeStyle(.secondary)
        }
    }
}
