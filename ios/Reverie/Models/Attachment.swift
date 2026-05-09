//
//  Attachment.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@Model
final class Attachment {
    var id: UUID = UUID()
    var itemId: UUID = UUID()
    var itemType: AttachmentItemType = AttachmentItemType.task
    var fileName: String = ""
    var fileExtension: String = ""
    var fileSize: Int64 = 0 // in bytes
    var mimeType: String = "application/octet-stream"
    var attachmentType: AttachmentType = AttachmentType.other
    var localURL: String? // Local file path
    var cloudURL: String? // CloudKit URL
    var thumbnailData: Data? // Thumbnail for images
    var createdAt: Date = Date()
    var uploadedAt: Date?
    var isUploaded: Bool = false
    
    init(
        id: UUID = UUID(),
        itemId: UUID,
        itemType: AttachmentItemType,
        fileName: String,
        fileExtension: String,
        fileSize: Int64,
        mimeType: String,
        attachmentType: AttachmentType,
        localURL: String? = nil,
        cloudURL: String? = nil,
        thumbnailData: Data? = nil,
        createdAt: Date = Date(),
        uploadedAt: Date? = nil,
        isUploaded: Bool = false
    ) {
        self.id = id
        self.itemId = itemId
        self.itemType = itemType
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.attachmentType = attachmentType
        self.localURL = localURL
        self.cloudURL = cloudURL
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
        self.uploadedAt = uploadedAt
        self.isUploaded = isUploaded
    }
    
    // Computed properties
    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var fileIcon: String {
        switch attachmentType {
        case .image: return "photo.fill"
        case .video: return "video.fill"
        case .audio: return "waveform"
        case .document: return "doc.fill"
        case .pdf: return "doc.text.fill"
        case .other: return "paperclip"
        }
    }
    
    var fileIconColor: Color {
        switch attachmentType {
        case .image: return .blue
        case .video: return .purple
        case .audio: return .green
        case .document: return .orange
        case .pdf: return .red
        case .other: return .gray
        }
    }
}

// MARK: - Enums

enum AttachmentItemType: String, Codable {
    case task
    case journey
    case plan
    case routine
    case milestone
}

enum AttachmentType: String, Codable, CaseIterable {
    case image
    case video
    case audio
    case document
    case pdf
    case other
    
    var displayName: String {
        switch self {
        case .image: return "Image"
        case .video: return "Video"
        case .audio: return "Audio"
        case .document: return "Document"
        case .pdf: return "PDF"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .image: return "photo.fill"
        case .video: return "video.fill"
        case .audio: return "waveform"
        case .document: return "doc.fill"
        case .pdf: return "doc.text.fill"
        case .other: return "paperclip"
        }
    }
    
    static func fromMimeType(_ mimeType: String) -> AttachmentType {
        if mimeType.starts(with: "image/") {
            return .image
        } else if mimeType.starts(with: "video/") {
            return .video
        } else if mimeType.starts(with: "audio/") {
            return .audio
        } else if mimeType == "application/pdf" {
            return .pdf
        } else if mimeType.starts(with: "text/") || mimeType.contains("word") || mimeType.contains("document") {
            return .document
        } else {
            return .other
        }
    }
    
    static func fromFileExtension(_ ext: String) -> AttachmentType {
        let lowercased = ext.lowercased()
        switch lowercased {
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tiff":
            return .image
        case "mp4", "mov", "avi", "mkv", "m4v", "wmv":
            return .video
        case "mp3", "m4a", "wav", "aac", "flac", "ogg":
            return .audio
        case "pdf":
            return .pdf
        case "doc", "docx", "txt", "rtf", "pages", "odt":
            return .document
        default:
            return .other
        }
    }
}

// MARK: - Storage Manager

class AttachmentStorageManager {
    static let shared = AttachmentStorageManager()
    
    private init() {}
    
    // Get documents directory
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // Get attachments directory
    var attachmentsDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    // Save file to local storage
    func saveFile(from sourceURL: URL, for itemId: UUID) throws -> (localURL: String, fileSize: Int64, fileName: String, fileExtension: String) {
        let fileName = sourceURL.lastPathComponent
        let fileExtension = sourceURL.pathExtension
        let destinationURL = attachmentsDirectory
            .appendingPathComponent(itemId.uuidString)
            .appendingPathComponent(fileName)
        
        // Create item directory
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        // Copy file
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        return (destinationURL.path, fileSize, fileName, fileExtension)
    }
    
    // Delete file from local storage
    func deleteFile(at localPath: String) throws {
        let url = URL(fileURLWithPath: localPath)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    // Get file URL
    func getFileURL(for attachment: Attachment) -> URL? {
        guard let localURL = attachment.localURL else { return nil }
        let url = URL(fileURLWithPath: localURL)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    // Generate thumbnail for image
    func generateThumbnail(for imageURL: URL, maxSize: CGSize = CGSize(width: 200, height: 200)) -> Data? {
        #if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: imageURL.path) else { return nil }
        
        let scale = min(maxSize.width / image.size.width, maxSize.height / image.size.height)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return thumbnail?.jpegData(compressionQuality: 0.8)
        #else
        return nil
        #endif
    }
    
    // Calculate total storage used
    func calculateTotalStorage() -> Int64 {
        var totalSize: Int64 = 0
        
        guard let enumerator = FileManager.default.enumerator(
            at: attachmentsDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let fileSize = attributes[.size] as? Int64 else { continue }
            totalSize += fileSize
        }
        
        return totalSize
    }
    
    // Format storage size
    func formatStorageSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
