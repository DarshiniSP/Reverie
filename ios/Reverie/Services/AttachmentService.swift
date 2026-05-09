//
//  AttachmentService.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

class AttachmentService {
    static let shared = AttachmentService()
    
    private init() {}
    
    // MARK: - Create Attachment
    
    func addAttachment(
        itemId: UUID,
        itemType: AttachmentItemType,
        fileURL: URL,
        context: ModelContext
    ) throws -> Attachment {
        // Save file to local storage
        let storage = AttachmentStorageManager.shared
        let (localPath, fileSize, fileName, fileExtension) = try storage.saveFile(from: fileURL, for: itemId)
        
        // Determine MIME type
        let mimeType = getMimeType(for: fileExtension)
        let attachmentType = AttachmentType.fromFileExtension(fileExtension)
        
        // Generate thumbnail for images
        var thumbnailData: Data? = nil
        if attachmentType == .image {
            thumbnailData = storage.generateThumbnail(for: URL(fileURLWithPath: localPath))
        }
        
        // Create attachment
        let attachment = Attachment(
            itemId: itemId,
            itemType: itemType,
            fileName: fileName,
            fileExtension: fileExtension,
            fileSize: fileSize,
            mimeType: mimeType,
            attachmentType: attachmentType,
            localURL: localPath,
            thumbnailData: thumbnailData
        )
        
        context.insert(attachment)
        try context.save()
        
        return attachment
    }
    
    // MARK: - Add from Photo Library
    
    func addPhotoAttachment(
        itemId: UUID,
        itemType: AttachmentItemType,
        photoItem: PhotosPickerItem,
        context: ModelContext
    ) async throws -> Attachment {
        // Load transferable image
        guard let imageData = try? await photoItem.loadTransferable(type: Data.self) else {
            throw AttachmentError.failedToLoadPhoto
        }
        
        // Save to temporary location
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        try imageData.write(to: tempURL)
        
        // Add as attachment
        let attachment = try addAttachment(
            itemId: itemId,
            itemType: itemType,
            fileURL: tempURL,
            context: context
        )
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)
        
        return attachment
    }
    
    // MARK: - Delete Attachment
    
    func deleteAttachment(_ attachment: Attachment, context: ModelContext) throws {
        // Delete local file
        if let localURL = attachment.localURL {
            try? AttachmentStorageManager.shared.deleteFile(at: localURL)
        }
        
        // Delete from database
        context.delete(attachment)
        try context.save()
    }
    
    func deleteAllAttachments(for itemId: UUID, context: ModelContext) throws {
        // Safe deletion that ignores missing files
        let attachments = getAttachments(for: itemId, context: context)
        for attachment in attachments {
            // Delete local file but don't fail if missing
            if let localURL = attachment.localURL {
                try? AttachmentStorageManager.shared.deleteFile(at: localURL)
            }
            
            // Delete from database
            context.delete(attachment)
        }
        
        // Save once after all deletions to reduce context thrashing
        // Note: The caller (TaskDetailView) might save the context too when deleting the Task,
        // so we could optionally skip saving here if we trust the caller.
        // But to be safe, we save here.
        try? context.save()
    }
    
    // MARK: - Get Attachments
    
    func getAttachments(for itemId: UUID, context: ModelContext) -> [Attachment] {
        let descriptor = FetchDescriptor<Attachment>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        let allAttachments = (try? context.fetch(descriptor)) ?? []
        return allAttachments.filter { $0.itemId == itemId }
    }
    
    func getAttachments(for itemId: UUID, type: AttachmentType, context: ModelContext) -> [Attachment] {
        let all = getAttachments(for: itemId, context: context)
        return all.filter { $0.attachmentType == type }
    }
    
    // MARK: - Storage Management
    
    func getTotalStorageUsed() -> Int64 {
        return AttachmentStorageManager.shared.calculateTotalStorage()
    }
    
    func getStorageUsedFormatted() -> String {
        let size = getTotalStorageUsed()
        return AttachmentStorageManager.shared.formatStorageSize(size)
    }
    
    func cleanupOrphanedFiles(context: ModelContext) throws {
        // Get all attachments from database
        let descriptor = FetchDescriptor<Attachment>()
        let allAttachments = try context.fetch(descriptor)
        let validPaths = Set(allAttachments.compactMap { $0.localURL })
        
        // Get all files in attachments directory
        let storage = AttachmentStorageManager.shared
        guard let enumerator = FileManager.default.enumerator(
            at: storage.attachmentsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        
        // Delete files not in database
        for case let fileURL as URL in enumerator {
            if !validPaths.contains(fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMimeType(for fileExtension: String) -> String {
        let ext = fileExtension.lowercased()
        
        // Common MIME types
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "heic", "heif": return "image/heic"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "txt": return "text/plain"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Errors

enum AttachmentError: LocalizedError {
    case failedToLoadPhoto
    case fileNotFound
    case storageLimitExceeded
    case unsupportedFileType
    
    var errorDescription: String? {
        switch self {
        case .failedToLoadPhoto:
            return "Failed to load photo from library"
        case .fileNotFound:
            return "File not found"
        case .storageLimitExceeded:
            return "Storage limit exceeded"
        case .unsupportedFileType:
            return "Unsupported file type"
        }
    }
}
