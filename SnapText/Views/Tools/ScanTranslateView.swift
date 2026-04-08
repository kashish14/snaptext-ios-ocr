import SwiftUI
import Translation

struct ScanTranslateView: View {
    @State private var showPicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showTranslation = false

    private let ocrService = OCRService()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image = selectedImage {
                    resultSection(image)
                } else {
                    emptyState
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Scan & Translate")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in
                selectedImage = image
                recognizedText = ""
                scanAndTranslate(image)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            LiveCameraView { image in
                selectedImage = image
                recognizedText = ""
                scanAndTranslate(image)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 80)
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.08))
                        .frame(width: 120, height: 120)
                    Image(systemName: "translate")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.green)
                }
                VStack(spacing: 8) {
                    Text("Scan & Translate")
                        .font(.title2.bold())
                    Text("Capture text from any image and translate instantly")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            Spacer(minLength: 80)
            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    showPicker = true
                } label: {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private func resultSection(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                .padding(.horizontal)

            if isProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Scanning text...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            if !recognizedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.blue)
                        Text("Scanned Text")
                            .font(.headline)
                    }
                    .padding(.horizontal)

                    SelectableTextView(text: recognizedText)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(4)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                }

                VStack(spacing: 10) {
                    Button {
                        showTranslation = true
                    } label: {
                        Label("Translate", systemImage: "translate")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .translationPresentation(isPresented: $showTranslation, text: recognizedText)

                    Button {
                        UIPasteboard.general.string = recognizedText
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Label("Copy Text", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    ShareLink(item: recognizedText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button { showCamera = true } label: {
                    Label("Retake", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button { showPicker = true } label: {
                    Label("Gallery", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
        }
    }

    private func scanAndTranslate(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let text = try await ocrService.recognizeText(in: image, mode: .accurate)
                await MainActor.run {
                    recognizedText = text
                    isProcessing = false
                    // Auto-open translation after scan
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showTranslation = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }
}
