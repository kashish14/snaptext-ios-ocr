import SwiftUI

struct HandwritingView: View {
    @State private var showPicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var copied = false

    private let ocrService = OCRService()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image = selectedImage {
                    imageSection(image)
                } else {
                    emptyState
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Handwriting OCR")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in
                selectedImage = image
                recognizedText = ""
                processHandwriting(image)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            LiveCameraView { image in
                selectedImage = image
                recognizedText = ""
                processHandwriting(image)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 80)
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.08))
                        .frame(width: 120, height: 120)
                    Image(systemName: "hand.draw")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.indigo)
                }
                VStack(spacing: 8) {
                    Text("Handwriting to Text")
                        .font(.title2.bold())
                    Text("Capture handwritten notes and convert to digital text")
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
                .tint(.indigo)
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

    private func imageSection(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                .padding(.horizontal)

            if isProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Reading handwriting...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
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
                            .foregroundStyle(.indigo)
                        Text("Recognized Text")
                            .font(.headline)
                        Spacer()
                        Text("\(recognizedText.split(separator: " ").count) words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                        UIPasteboard.general.string = recognizedText
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Label(copied ? "Copied!" : "Copy Text", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(copied ? .green : .indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    ShareLink(item: recognizedText) {
                        Label("Share Text", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    TranslateButton(text: recognizedText)
                }
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Retake", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    showPicker = true
                } label: {
                    Label("Gallery", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
        }
    }

    private func processHandwriting(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let text = try await ocrService.recognizeText(in: image, mode: .accurate)
                await MainActor.run {
                    recognizedText = text
                    isProcessing = false
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
