import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreTransferable
import UIKit

struct ACCImportedPhoto: Transferable {
    let temporaryURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("acc-import-\(UUID().uuidString)")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return ACCImportedPhoto(temporaryURL: destination)
        }
    }
}

struct ACCPhoto: Codable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    let originalExtension: String
    let originalBytes: Int64
    let width: Int
    let height: Int
}

enum ACCPhotoStoreError: LocalizedError {
    case unsupportedImage
    case imageTooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedImage: "이미지를 읽을 수 없습니다. 다른 사진을 선택해 주세요."
        case .imageTooLarge: "사진이 너무 큽니다. 200 MB 이하의 사진을 선택해 주세요."
        }
    }
}

actor ACCPhotoStore {
    static let shared = ACCPhotoStore()
    private let fileManager = FileManager.default
    private let maxOriginalBytes: Int64 = 200 * 1024 * 1024

    private var root: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ACC", isDirectory: true)
    }
    private var originals: URL { root.appendingPathComponent("Originals", isDirectory: true) }
    private var thumbnails: URL { root.appendingPathComponent("Thumbnails", isDirectory: true) }
    private var manifest: URL { root.appendingPathComponent("photos.json") }

    func photos() throws -> [ACCPhoto] {
        guard fileManager.fileExists(atPath: manifest.path) else { return [] }
        return try JSONDecoder().decode([ACCPhoto].self, from: Data(contentsOf: manifest))
            .sorted { $0.createdAt > $1.createdAt }
    }

    func add(from temporaryURL: URL) throws -> ACCPhoto {
        defer { try? fileManager.removeItem(at: temporaryURL) }
        let values = try temporaryURL.resourceValues(forKeys: [.fileSizeKey])
        let byteCount = Int64(values.fileSize ?? 0)
        guard byteCount > 0, byteCount <= maxOriginalBytes else { throw ACCPhotoStoreError.imageTooLarge }
        guard let source = CGImageSourceCreateWithURL(temporaryURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0,
              let type = CGImageSourceGetType(source),
              let extensionName = UTType(type as String)?.preferredFilenameExtension else {
            throw ACCPhotoStoreError.unsupportedImage
        }
        try fileManager.createDirectory(at: originals, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbnails, withIntermediateDirectories: true)
        let id = UUID()
        let originalURL = originals.appendingPathComponent("\(id.uuidString).\(extensionName)")
        let thumbnailURL = thumbnails.appendingPathComponent("\(id.uuidString).jpg")
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 512,
            kCGImageSourceShouldCache: false
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let jpeg = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.75) else {
            throw ACCPhotoStoreError.unsupportedImage
        }
        do {
            try fileManager.copyItem(at: temporaryURL, to: originalURL)
            try jpeg.write(to: thumbnailURL, options: .atomic)
            let photo = ACCPhoto(id: id, createdAt: .now, originalExtension: extensionName,
                                 originalBytes: byteCount, width: width, height: height)
            var all = try photos()
            all.insert(photo, at: 0)
            try JSONEncoder().encode(all).write(to: manifest, options: .atomic)
            return photo
        } catch {
            try? fileManager.removeItem(at: originalURL)
            try? fileManager.removeItem(at: thumbnailURL)
            throw error
        }
    }

    func thumbnailData(for photo: ACCPhoto) throws -> Data {
        try Data(contentsOf: thumbnails.appendingPathComponent("\(photo.id.uuidString).jpg"))
    }

    func remove(_ photo: ACCPhoto) throws {
        var all = try photos()
        all.removeAll { $0.id == photo.id }
        try JSONEncoder().encode(all).write(to: manifest, options: .atomic)
        try? fileManager.removeItem(at: originals.appendingPathComponent("\(photo.id.uuidString).\(photo.originalExtension)"))
        try? fileManager.removeItem(at: thumbnails.appendingPathComponent("\(photo.id.uuidString).jpg"))
    }
}

