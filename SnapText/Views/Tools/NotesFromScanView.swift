import SwiftUI

struct NotesFromScanView: View {
    @Environment(\.toolContext) private var toolContext
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var isProcessing = false
    @State private var noteText = ""
    @State private var noteTitle = ""
    @State private var isSaved = false
    @State private var errorMessage: String?
    @State private var didApplyContext = false

    private let ocrService = OCRService()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if noteText.isEmpty && !isProcessing {
                    Spacer(minLength: 60)
                    VStack(spacing: 24) {
                        Image(systemName: "note.text")
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)

                        VStack(spacing: 8) {
                            Text("Notes from Scan")
                                .font(.title2.bold())
                            Text("Scan a whiteboard, handwritten note, or document and save as clean text")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal)
                    Spacer(minLength: 60)

                    HStack(spacing: 12) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            showGallery = true
                        } label: {
                            Label("Gallery", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                } else if isProcessing {
                    Spacer(minLength: 100)
                    ProgressView("Extracting text...")
                    Spacer(minLength: 100)
                } else {
                    // Editable note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Note title", text: $noteTitle)
                            .font(.headline)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $noteText)
                            .frame(minHeight: 250)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal)

                    // Actions
                    VStack(spacing: 12) {
                        Button {
                            saveToAppleNotes()
                        } label: {
                            Label(isSaved ? "Copied to Clipboard!" : "Copy Note", systemImage: isSaved ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        ShareLink(item: formatNote()) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        HStack(spacing: 12) {
                            Button {
                                showCamera = true
                            } label: {
                                Label("Re-scan", systemImage: "camera.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)

                            Button(role: .destructive) {
                                noteText = ""
                                noteTitle = ""
                                isSaved = false
                            } label: {
                                Label("Clear", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Notes from Scan")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !didApplyContext, let text = toolContext.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                didApplyContext = true
                noteText = cleanupText(text)
                noteTitle = generateTitle(from: noteText)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                Task { await processImage(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showGallery) {
            ImagePicker { image in
                Task { await processImage(image) }
            }
        }
    }

    private func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        do {
            let text = try await ocrService.recognizeText(in: image, mode: .accurate)
            noteText = cleanupText(text)
            noteTitle = generateTitle(from: noteText)
        } catch {
            errorMessage = "Could not extract text."
        }
        isProcessing = false
    }

    private func cleanupText(_ text: String) -> String {
        // Clean up OCR artifacts: merge broken lines, fix spacing
        let lines = text.components(separatedBy: "\n")
        var cleaned: [String] = []
        var current = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !current.isEmpty {
                    cleaned.append(current)
                    current = ""
                }
                cleaned.append("")
            } else if current.isEmpty {
                current = trimmed
            } else if trimmed.first?.isUppercase == true || trimmed.hasPrefix("-") || trimmed.hasPrefix("\u{2022}") {
                cleaned.append(current)
                current = trimmed
            } else {
                current += " " + trimmed
            }
        }
        if !current.isEmpty {
            cleaned.append(current)
        }

        return cleaned.joined(separator: "\n")
    }

    private func generateTitle(from text: String) -> String {
        let firstLine = text.components(separatedBy: "\n").first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? "Scanned Note"
        let maxLen = 50
        if firstLine.count <= maxLen { return firstLine }
        return String(firstLine.prefix(maxLen)) + "..."
    }

    private func formatNote() -> String {
        if noteTitle.isEmpty { return noteText }
        return "\(noteTitle)\n\n\(noteText)"
    }

    private func saveToAppleNotes() {
        ClipboardManager.shared.copy(formatNote(), source: "Note")
        isSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isSaved = false }
    }
}
