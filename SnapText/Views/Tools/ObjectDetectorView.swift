import SwiftUI
import Vision

/// On-device object classification using Vision's built-in classifier.
struct ObjectDetectorView: View {
    @State private var showPicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var detectedObjects: [DetectedObject] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?

    struct DetectedObject: Identifiable {
        let id = UUID()
        let label: String
        let confidence: Float
        let boundingBox: CGRect  // normalized Vision coordinates
    }

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
        .navigationTitle("Object Detector")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in
                selectedImage = image
                detectObjects(in: image)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            LiveCameraView { image in
                selectedImage = image
                detectObjects(in: image)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 80)
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.08))
                        .frame(width: 120, height: 120)
                    Image(systemName: "eye.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.teal)
                }
                VStack(spacing: 8) {
                    Text("Object Detector")
                        .font(.title2.bold())
                    Text("Identify objects, animals, food, and more using on-device AI")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            Spacer(minLength: 80)
            HStack(spacing: 12) {
                Button { showCamera = true } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button { showPicker = true } label: {
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
            // Image with bounding boxes overlay
            GeometryReader { geo in
                let imgSize = imageFitSize(image: image, in: geo.size)
                let xOffset = (geo.size.width - imgSize.width) / 2
                let yOffset = (geo.size.height - imgSize.height) / 2

                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    ForEach(detectedObjects) { obj in
                        let rect = convertBBox(obj.boundingBox, imageSize: imgSize)
                        Rectangle()
                            .stroke(Color.teal, lineWidth: 2)
                            .frame(width: rect.width, height: rect.height)
                            .overlay(alignment: .topLeading) {
                                Text(obj.label)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.teal)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .offset(y: -18)
                            }
                            .offset(x: rect.minX + xOffset, y: rect.minY + yOffset)
                    }
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            if isProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Detecting objects...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = errorMessage {
                Text(error).font(.callout).foregroundStyle(.red).padding(.horizontal)
            }

            // Results list
            if !detectedObjects.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sparkles").foregroundStyle(.teal)
                        Text("Detected \(detectedObjects.count) objects").font(.headline)
                    }
                    .padding(.horizontal)

                    ForEach(detectedObjects) { obj in
                        HStack(spacing: 12) {
                            Image(systemName: "cube.fill")
                                .foregroundStyle(.teal)
                                .frame(width: 32, height: 32)
                                .background(Color.teal.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(obj.label.capitalized)
                                    .font(.subheadline.weight(.medium))
                                Text("\(Int(obj.confidence * 100))% confidence")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // Confidence bar
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 60, height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.teal.gradient)
                                    .frame(width: 60 * CGFloat(obj.confidence), height: 8)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }

                // Copy results
                Button {
                    let text = detectedObjects.map { "\($0.label.capitalized) (\(Int($0.confidence * 100))%)" }.joined(separator: "\n")
                    UIPasteboard.general.string = text
                    Haptics.success()
                } label: {
                    Label("Copy Results", systemImage: "doc.on.doc")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button { showCamera = true } label: {
                    Label("Retake", systemImage: "camera").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
                Button { showPicker = true } label: {
                    Label("Gallery", systemImage: "photo").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Detection

    private func detectObjects(in image: UIImage) {
        isProcessing = true
        errorMessage = nil
        detectedObjects = []

        Task.detached {
            guard let cgImage = image.fixedOrientation().cgImage else {
                await MainActor.run {
                    errorMessage = "Invalid image"
                    isProcessing = false
                }
                return
            }

            do {
                // Use VNClassifyImageRequest for image classification
                let classifyRequest = VNClassifyImageRequest()
                // Use VNRecognizeAnimalsRequest for animal detection
                let animalRequest = VNRecognizeAnimalsRequest()

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([classifyRequest, animalRequest])

                var objects: [DetectedObject] = []

                // Classification results (top labels)
                if let classifications = classifyRequest.results {
                    let topResults = classifications
                        .filter { $0.confidence > 0.1 }
                        .prefix(8)
                    for result in topResults {
                        objects.append(DetectedObject(
                            label: result.identifier.replacingOccurrences(of: "_", with: " "),
                            confidence: result.confidence,
                            boundingBox: .zero
                        ))
                    }
                }

                // Animal detection with bounding boxes
                if let animals = animalRequest.results {
                    for animal in animals {
                        for label in animal.labels {
                            objects.append(DetectedObject(
                                label: label.identifier,
                                confidence: label.confidence,
                                boundingBox: animal.boundingBox
                            ))
                        }
                    }
                }

                await MainActor.run { [objects] in
                    detectedObjects = objects
                    isProcessing = false
                    if objects.isEmpty {
                        errorMessage = "No objects detected"
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

    // MARK: - Geometry helpers

    private func imageFitSize(image: UIImage, in containerSize: CGSize) -> CGSize {
        let aspect = image.size.width / image.size.height
        if aspect > containerSize.width / containerSize.height {
            let w = containerSize.width
            return CGSize(width: w, height: w / aspect)
        } else {
            let h = containerSize.height
            return CGSize(width: h * aspect, height: h)
        }
    }

    private func convertBBox(_ bbox: CGRect, imageSize: CGSize) -> CGRect {
        // Vision uses bottom-left origin, SwiftUI uses top-left
        let x = bbox.origin.x * imageSize.width
        let y = (1 - bbox.origin.y - bbox.height) * imageSize.height
        let w = bbox.width * imageSize.width
        let h = bbox.height * imageSize.height
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
