import SwiftUI

#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Attachment Item Model

/// Represents a single image attachment in the upload pipeline.
internal struct AttachmentItem: Identifiable {
    let id = UUID()
    let imageData: Data
    let filename: String
    let mimeType: String
    var uploadedUrl: String?
    var isUploading: Bool = true
    var error: String?

    #if canImport(UIKit)
    var thumbnail: UIImage? {
        UIImage(data: imageData)
    }
    #elseif canImport(AppKit)
    var thumbnail: NSImage? {
        NSImage(data: imageData)
    }
    #endif
}

// MARK: - ImageAttachmentView

/// A SwiftUI view that handles image selection, upload, and preview for feedback attachments.
///
/// Supports:
/// - PhotosPicker (iOS 16+)
/// - UIImagePickerController fallback (iOS 15)
/// - NSOpenPanel (macOS)
/// - Clipboard paste
///
/// The view manages its own upload state and exposes the resulting URLs via a binding.
@available(iOS 15.0, macOS 12.0, *)
internal struct ImageAttachmentView: View {
    let projectId: String
    let baseURL: String
    @Binding var urls: [String]

    @State private var items: [AttachmentItem] = []
    @State private var showingPicker = false

    private let maxImages = 2
    private let maxFileSize = 5 * 1024 * 1024 // 5 MB

    private var canAddMore: Bool {
        items.count < maxImages
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail strip
            if !items.isEmpty {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        thumbnailView(for: item)
                    }

                    if canAddMore {
                        addMoreButton
                    }
                }
            }

            // Action buttons row
            HStack(spacing: 12) {
                if items.isEmpty {
                    attachButton
                }

                pasteButton
            }
        }
    }

    // MARK: - Subviews

    private func thumbnailView(for item: AttachmentItem) -> some View {
        ZStack(alignment: .topTrailing) {
            #if canImport(UIKit)
            if let uiImage = item.thumbnail {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            #elseif canImport(AppKit)
            if let nsImage = item.thumbnail {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            #endif

            // Uploading overlay
            if item.isUploading {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay(ProgressView().tint(.white))
            }

            // Error overlay
            if item.error != nil {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                    )
            }

            // Remove button
            if !item.isUploading {
                Button {
                    removeItem(item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.6)).frame(width: 16, height: 16))
                }
                .offset(x: 4, y: -4)
            }
        }
        .frame(width: 48, height: 48)
    }

    private var addMoreButton: some View {
        Button {
            showingPicker = true
        } label: {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundColor(Color.secondary.opacity(0.4))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                )
        }
        .buttonStyle(.plain)
        .modifier(PickerModifier(isPresented: $showingPicker, onImageSelected: handleImageData))
    }

    private var attachButton: some View {
        Button {
            showingPicker = true
        } label: {
            Label("Attach Image", systemImage: "photo.badge.plus")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!canAddMore)
        .modifier(PickerModifier(isPresented: $showingPicker, onImageSelected: handleImageData))
    }

    private var pasteButton: some View {
        Button {
            pasteFromClipboard()
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!canAddMore || !clipboardHasImage)
    }

    // MARK: - Clipboard

    private var clipboardHasImage: Bool {
        #if canImport(UIKit)
        return UIPasteboard.general.hasImages
        #elseif canImport(AppKit)
        return NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil)
        #else
        return false
        #endif
    }

    private func pasteFromClipboard() {
        guard canAddMore else { return }

        #if canImport(UIKit)
        guard let image = UIPasteboard.general.image,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        handleImageData(data, filename: "clipboard-\(Int(Date().timeIntervalSince1970)).jpg", mimeType: "image/jpeg")
        #elseif canImport(AppKit)
        guard let images = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil),
              let nsImage = images.first as? NSImage,
              let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else { return }
        handleImageData(data, filename: "clipboard-\(Int(Date().timeIntervalSince1970)).jpg", mimeType: "image/jpeg")
        #endif
    }

    // MARK: - Upload Logic

    private func handleImageData(_ data: Data, filename: String, mimeType: String) {
        guard canAddMore else { return }
        guard data.count <= maxFileSize else { return }

        var item = AttachmentItem(imageData: data, filename: filename, mimeType: mimeType)
        items.append(item)
        let itemId = item.id

        Task {
            do {
                let url = try await APIClient.shared.uploadImage(
                    projectId: projectId,
                    baseURL: baseURL,
                    imageData: data,
                    filename: filename,
                    mimeType: mimeType
                )
                await MainActor.run {
                    if let idx = items.firstIndex(where: { $0.id == itemId }) {
                        items[idx].uploadedUrl = url
                        items[idx].isUploading = false
                        syncUrls()
                    }
                }
            } catch {
                await MainActor.run {
                    if let idx = items.firstIndex(where: { $0.id == itemId }) {
                        items[idx].isUploading = false
                        items[idx].error = error.localizedDescription
                    }
                }
            }
        }
    }

    private func removeItem(_ id: UUID) {
        items.removeAll { $0.id == id }
        syncUrls()
    }

    private func syncUrls() {
        urls = items.compactMap { $0.uploadedUrl }
    }
}

// MARK: - Platform-specific Picker

@available(iOS 15.0, macOS 12.0, *)
private struct PickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onImageSelected: (Data, String, String) -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            content.photosPicker(
                isPresented: $isPresented,
                selection: Binding(
                    get: { nil },
                    set: { item in
                        guard let item = item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                await MainActor.run {
                                    onImageSelected(data, "photo-\(Int(Date().timeIntervalSince1970)).jpg", "image/jpeg")
                                }
                            }
                        }
                    }
                ),
                matching: .images
            )
        } else {
            content.sheet(isPresented: $isPresented) {
                LegacyImagePicker { data, filename, mimeType in
                    onImageSelected(data, filename, mimeType)
                    isPresented = false
                }
            }
        }
        #elseif os(macOS)
        content.onChange(of: isPresented) { newValue in
            guard newValue else { return }
            isPresented = false

            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.jpeg, .png, .gif, .webP]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false

            if panel.runModal() == .OK, let url = panel.url,
               let data = try? Data(contentsOf: url) {
                let filename = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                let mimeType: String
                switch ext {
                case "png": mimeType = "image/png"
                case "gif": mimeType = "image/gif"
                case "webp": mimeType = "image/webp"
                default: mimeType = "image/jpeg"
                }
                onImageSelected(data, filename, mimeType)
            }
        }
        #endif
    }
}

// MARK: - Legacy Image Picker (iOS 15)

#if os(iOS)
@available(iOS 15.0, *)
private struct LegacyImagePicker: UIViewControllerRepresentable {
    let onImageSelected: (Data, String, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (Data, String, String) -> Void

        init(onImageSelected: @escaping (Data, String, String) -> Void) {
            self.onImageSelected = onImageSelected
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.8) else { return }
            onImageSelected(data, "photo-\(Int(Date().timeIntervalSince1970)).jpg", "image/jpeg")
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif
