//
//  AttachmentsView.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct AttachmentsView: View {
    @Environment(\.modelContext) private var modelContext
    
    let itemId: UUID
    let itemType: AttachmentItemType
    
    @Query private var allAttachments: [Attachment]
    @State private var showingPhotoPicker = false
    @State private var showingDocumentPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedAttachment: Attachment?
    @State private var isLoading = false
    
    init(itemId: UUID, itemType: AttachmentItemType) {
        self.itemId = itemId
        self.itemType = itemType
        
        _allAttachments = Query(
            sort: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }
    
    private var attachments: [Attachment] {
        allAttachments.filter { $0.itemId == itemId }
    }
    
    private var imageAttachments: [Attachment] {
        attachments.filter { $0.attachmentType == .image }
    }
    
    private var documentAttachments: [Attachment] {
        attachments.filter { $0.attachmentType != .image }
    }
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // ... existing init ...
    // Note: I am not modifying init, just adding state above it. 
    // Wait, the tool requires me to respect lines. 
    // I will replace start of body to end.
    
    var body: some View {
        ScrollView {
            // ... (keep content same until alert) ...
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Add Button
                    Menu {
                        Button {
                            showingPhotoPicker = true
                        } label: {
                            Label("Photo Library", systemImage: "photo")
                        }
                        
                        Button {
                            showingDocumentPicker = true
                        } label: {
                            Label("Choose File", systemImage: "doc")
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(DSFonts.headline())
                            Text("Add")
                                .font(DSFonts.caption())
                        }
                        .foregroundColor(DSColors.accentPrimary)
                        .frame(width: 80, height: 80)
                        .background(DSColors.accentPrimary.opacity(0.1))
                        .cornerRadius(UIConstants.CornerRadius.large)
                        .overlay(
                            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.large)
                                .strokeBorder(DSColors.accentPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                    }
                    
                    // Attachments List
                    ForEach(attachments) { attachment in
                        CompactAttachmentThumbnail(attachment: attachment)
                            .onTapGesture {
                                selectedAttachment = attachment
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteAttachment(attachment)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItems,
            matching: .images
        )
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.item], // Allow all items to ensure PDFs are selectable
            allowsMultipleSelection: false
        ) { result in
            handleDocumentSelection(result)
        }
        .sheet(item: $selectedAttachment) { attachment in
            AttachmentDetailView(attachment: attachment)
        }
        .alert("Attachment", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            DispatchQueue.main.async {
                _Concurrency.Task {
                    await self.handlePhotoSelection(newItems)
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
    }
    
    private func deleteAttachment(_ attachment: Attachment) {
        do {
            try AttachmentService.shared.deleteAttachment(attachment, context: modelContext)
        } catch {
            showFeedback("Failed to delete attachment: \(error.localizedDescription)")
        }
    }
    
    private func showFeedback(_ message: String) {
        alertMessage = message
        showAlert = true
    }
    
    private func handlePhotoSelection(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isLoading = true
        
        for item in items {
            do {
                _ = try await AttachmentService.shared.addPhotoAttachment(
                    itemId: itemId,
                    itemType: itemType,
                    photoItem: item,
                    context: modelContext
                )
            } catch {
                await MainActor.run {
                    showFeedback("Failed to add photo: \(error.localizedDescription)")
                }
            }
        }
        
        selectedPhotoItems = []
        isLoading = false
    }
    
    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                showFeedback("Permission denied to access the selected file.")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                _ = try AttachmentService.shared.addAttachment(
                    itemId: itemId,
                    itemType: itemType,
                    fileURL: url,
                    context: modelContext
                )
                // Success - swiftdata query will update UI
            } catch {
                showFeedback("Failed to add document: \(error.localizedDescription)")
            }
            
        case .failure(let error):
            showFeedback("Document selection failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Empty State

struct EmptyAttachmentsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "paperclip")
                .font(.system(size: 60))
                .foregroundColor(DSColors.textSecondary)
            
            Text("No Attachments")
                .font(DSFonts.headline())
            
            Text("Add photos or files to keep everything in one place")
                .font(DSFonts.label())
                .foregroundColor(DSColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Image Grid

struct ImageGridView: View {
    let attachments: [Attachment]
    let onTap: (Attachment) -> Void
    let onDelete: (Attachment) -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(attachments) { attachment in
                ImageThumbnailView(attachment: attachment)
                    .onTapGesture {
                        onTap(attachment)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            onDelete(attachment)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .padding(.horizontal)
    }
}

struct ImageThumbnailView: View {
    let attachment: Attachment
    
    var body: some View {
        Group {
            if let thumbnailData = attachment.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let url = AttachmentStorageManager.shared.getFileURL(for: attachment),
                      let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .foregroundColor(DSColors.textSecondary)
            }
        }
        .frame(width: 110, height: 110)
        .clipped()
        .cornerRadius(UIConstants.CornerRadius.standard)
    }
}

// MARK: - Document Row

struct DocumentRowView: View {
    let attachment: Attachment
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: attachment.fileIcon)
                .font(DSFonts.headline())
                .foregroundColor(attachment.fileIconColor)
                .frame(width: 40, height: 40)
                .background(attachment.fileIconColor.opacity(0.1))
                .cornerRadius(UIConstants.CornerRadius.standard)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.fileName)
                    .font(DSFonts.body())
                    .lineLimit(1)
                
                HStack {
                    Text(attachment.attachmentType.displayName)
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                    
                    Text("•")
                        .foregroundColor(DSColors.textSecondary)
                    
                    Text(attachment.fileSizeFormatted)
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

// MARK: - Storage Info

struct StorageInfoView: View {
    @State private var storageUsed: String = "Calculating..."
    
    var body: some View {
        HStack {
            Image(systemName: "internaldrive")
                .foregroundColor(DSColors.textSecondary)
            
            Text("Storage Used:")
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
            
            Text(storageUsed)
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
            
            Spacer()
        }
        .onAppear {
            storageUsed = AttachmentService.shared.getStorageUsedFormatted()
        }
    }
}

#Preview {
    AttachmentsView(itemId: UUID(), itemType: .task)
        .modelContainer(for: [Attachment.self], inMemory: true)
}

// MARK: - Compact Thumbnail
struct CompactAttachmentThumbnail: View {
    let attachment: Attachment
    
    var body: some View {
        VStack(spacing: 0) {
            // Preview Image/Icon
            Group {
                if attachment.attachmentType == .image,
                   let thumbnailData = attachment.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if attachment.attachmentType == .image,
                          let url = AttachmentStorageManager.shared.getFileURL(for: attachment),
                          let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // File Icon
                    ZStack {
                        Color(hex: "#F2F2F7") // Light gray background
                        Image(systemName: attachment.fileIcon)
                            .font(DSFonts.headline())
                            .foregroundColor(attachment.fileIconColor)
                    }
                }
            }
            .frame(width: 80, height: 60)
            .clipped()
            
            // Filename footer
            HStack {
                Text(attachment.fileName)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .foregroundColor(DSColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(width: 80)
            .background(DSColors.canvasSecondary)
        }
        .cornerRadius(UIConstants.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.large)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
