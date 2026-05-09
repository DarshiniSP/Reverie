//
//  AttachmentDetailView.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import SwiftUI
import SwiftData
import QuickLook

struct AttachmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let attachment: Attachment
    
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var fileURL: URL?
    @State private var previewURL: URL?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview
                    PreviewSection(attachment: attachment)
                        .onTapGesture {
                            if let url = AttachmentStorageManager.shared.getFileURL(for: attachment) {
                                previewURL = url
                            }
                        }
                    
                    // Info
                    InfoSection(attachment: attachment)
                }
                .padding()
            }
            .navigationTitle("Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Quick Look Preview
                        Button(action: {
                            if let url = AttachmentStorageManager.shared.getFileURL(for: attachment) {
                                previewURL = url
                            }
                        }) {
                            Label("Preview", systemImage: "eye")
                        }
                        
                        // Share
                        Button(action: {
                            // Ensure URL is ready before sharing
                            if let url = AttachmentStorageManager.shared.getFileURL(for: attachment) {
                                fileURL = url
                                // Small delay to ensure state update works if called from menu
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showingShareSheet = true
                                }
                            }
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        // Delete
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Delete Attachment", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAttachment()
                }
            } message: {
                Text("Are you sure you want to delete this attachment? This action cannot be undone.")
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = fileURL {
                    ShareSheet(items: [url])
                }
            }
            .quickLookPreview($previewURL)
        }
        .task {
            // Auto-open preview for all attachments to streamline flow
            // Add slight delay to allow navigation transition to complete
            try? await Task.sleep(for: .seconds(0.6))
            if let url = AttachmentStorageManager.shared.getFileURL(for: attachment) {
                await MainActor.run {
                    previewURL = url
                }
            }
        }
    }
    
    private func shareAttachment() {
        if let url = AttachmentStorageManager.shared.getFileURL(for: attachment) {
            fileURL = url
            showingShareSheet = true
        }
    }
    
    private func deleteAttachment() {
        do {
            try AttachmentService.shared.deleteAttachment(attachment, context: modelContext)
            dismiss()
        } catch {
            #if DEBUG
            print("Failed to delete attachment: \(error)")
            #endif
        }
    }
}

// MARK: - Preview Section

struct PreviewSection: View {
    let attachment: Attachment
    
    var body: some View {
        VStack(spacing: 12) {
            if attachment.attachmentType == .image {
                ImagePreview(attachment: attachment)
            } else {
                FilePreview(attachment: attachment)
            }
        }

    }
}

struct ImagePreview: View {
    let attachment: Attachment
    
    var body: some View {
        Group {
            if let thumbnailData = attachment.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let url = AttachmentStorageManager.shared.getFileURL(for: attachment),
                      let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 80))
                    .foregroundColor(DSColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(Color.black.opacity(0.05))
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

struct FilePreview: View {
    let attachment: Attachment
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: attachment.fileIcon)
                .font(.system(size: 80))
                .foregroundColor(attachment.fileIconColor)
            
            Text(attachment.fileName)
                .font(DSFonts.headline())
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

// MARK: - Info Section

struct InfoSection: View {
    let attachment: Attachment
    
    var body: some View {
        VStack(spacing: 0) {
            AttachmentInfoRow(label: "Name", value: attachment.fileName)
            Divider()
            AttachmentInfoRow(label: "Type", value: attachment.attachmentType.displayName)
            Divider()
            AttachmentInfoRow(label: "Size", value: attachment.fileSizeFormatted)
            Divider()
            AttachmentInfoRow(label: "Created", value: attachment.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

struct AttachmentInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(DSColors.textSecondary)
            
            Spacer()
            
            Text(value)
        }
        .padding()
    }
}

// MARK: - Share Sheet



#Preview {
    AttachmentDetailView(
        attachment: Attachment(
            itemId: UUID(),
            itemType: .task,
            fileName: "Document.pdf",
            fileExtension: "pdf",
            fileSize: 1024000,
            mimeType: "application/pdf",
            attachmentType: .pdf
        )
    )
    .modelContainer(for: [Attachment.self], inMemory: true)
}
