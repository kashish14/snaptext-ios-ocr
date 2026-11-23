import SwiftUI
import PencilKit

struct DocumentSigningView: View {
    @Environment(\.toolContext) private var toolContext
    @State private var showPicker = false
    @State private var selectedImage: UIImage?
    @State private var didApplyContext = false
    @State private var signatureImage: UIImage?
    @State private var showSignaturePad = false
    @State private var signaturePosition = CGSize.zero
    @State private var signatureScale: CGFloat = 1.0
    @State private var previewSize = CGSize.zero
    @State private var pdfData: Data?
    @State private var savedDrawing: PKDrawing?
    @State private var applyBW = false

    var body: some View {
        VStack(spacing: 0) {
            if selectedImage == nil {
                emptyState
            } else {
                signView
            }
        }
        .navigationTitle("Sign Document")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !didApplyContext, let img = toolContext.image, img.size.width > 0 {
                didApplyContext = true
                selectedImage = img
            }
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in
                selectedImage = image
                signatureImage = nil
                signaturePosition = .zero
                signatureScale = 1.0
                pdfData = nil
            }
        }
        .sheet(isPresented: $showSignaturePad) {
            SignaturePadSheet(existingDrawing: savedDrawing) { signature, drawing in
                signatureImage = signature
                savedDrawing = drawing
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "signature")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Sign Document")
                        .font(.title2.bold())
                    Text("Add your signature to any document or image")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            Spacer()

            Button {
                showPicker = true
            } label: {
                Label("Select Document", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private var signView: some View {
        VStack(spacing: 12) {
            // Document with signature overlay
            GeometryReader { geo in
                ZStack {
                    if let doc = selectedImage {
                        Image(uiImage: doc)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                    }

                    if let sig = signatureImage {
                        Image(uiImage: sig)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150 * signatureScale)
                            .offset(signaturePosition)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        signaturePosition = value.translation
                                    }
                            )
                            .gesture(
                                MagnifyGesture()
                                    .onChanged { value in
                                        signatureScale = value.magnification
                                    }
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { previewSize = $0 }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.top, 8)

            if signatureImage != nil {
                Text("Drag to position \u{2022} Pinch to resize")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // B&W toggle
            Toggle("Black & White PDF", isOn: $applyBW)
                .padding(.horizontal)
                .onChange(of: applyBW) { pdfData = nil }

            // Actions
            VStack(spacing: 12) {
                Button {
                    showSignaturePad = true
                } label: {
                    Label(signatureImage == nil ? "Add Signature" : "Change Signature", systemImage: "signature")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if signatureImage != nil {
                    Button {
                        exportSignedDocument()
                    } label: {
                        Label("Export Signed PDF", systemImage: "arrow.down.doc.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.green)
                }

                if let data = pdfData {
                    let transferable = PDFTransferable(data: data)
                    ShareLink(item: transferable, preview: SharePreview("Signed Document", image: Image(systemName: "doc.fill"))) {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                HStack(spacing: 12) {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Change Doc", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        selectedImage = nil
                        signatureImage = nil
                        pdfData = nil
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private func exportSignedDocument() {
        guard let doc = selectedImage, let sig = signatureImage else { return }

        let docSize = doc.size
        let renderer = UIGraphicsImageRenderer(size: docSize)
        let composited = renderer.image { ctx in
            let drawDoc = applyBW ? doc.blackAndWhite() : doc
            drawDoc.draw(in: CGRect(origin: .zero, size: docSize))

            // Map preview points to document pixels using the scaledToFit factor.
            let fit = min(previewSize.width / docSize.width, previewSize.height / docSize.height)
            let toDoc = fit > 0 ? 1 / fit : 1
            let sigWidth = 150 * signatureScale * toDoc
            let sigHeight = sigWidth * (sig.size.height / sig.size.width)
            let centerX = docSize.width / 2 + signaturePosition.width * toDoc
            let centerY = docSize.height / 2 + signaturePosition.height * toDoc
            let sigRect = CGRect(
                x: centerX - sigWidth / 2,
                y: centerY - sigHeight / 2,
                width: sigWidth,
                height: sigHeight
            )
            sig.draw(in: sigRect)
        }

        pdfData = PDFService.renderPDF(from: [composited])
    }
}

// MARK: - Signature Drawing Pad

struct SignaturePadSheet: View {
    let existingDrawing: PKDrawing?
    let onSign: (UIImage, PKDrawing) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var canvasView = PKCanvasView()
    @State private var selectedColor: Color = .black
    @State private var undoManager_: UndoManager?

    private let colorOptions: [(Color, UIColor)] = [
        (.black, .black),
        (.blue, .systemBlue),
        (.red, .systemRed),
        (.green, .systemGreen),
        (.purple, .systemPurple),
        (.orange, .systemOrange),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Draw your signature below")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                // Color palette
                HStack(spacing: 16) {
                    ForEach(colorOptions, id: \.1) { swiftUIColor, uiColor in
                        Button {
                            selectedColor = swiftUIColor
                            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: 3)
                        } label: {
                            Circle()
                                .fill(swiftUIColor)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if selectedColor == swiftUIColor {
                                        Circle()
                                            .stroke(.primary, lineWidth: 2.5)
                                            .frame(width: 34, height: 34)
                                    }
                                }
                        }
                    }

                    Divider()
                        .frame(height: 28)

                    // Eraser
                    Button {
                        canvasView.tool = PKEraserTool(.vector)
                        selectedColor = .clear
                    } label: {
                        Image(systemName: "eraser.fill")
                            .font(.title3)
                            .foregroundStyle(selectedColor == .clear ? .primary : .secondary)
                            .frame(width: 28, height: 28)
                    }
                }
                .padding(.top, 12)

                SignatureCanvasView(canvasView: $canvasView, existingDrawing: existingDrawing) { mgr in
                    undoManager_ = mgr
                }
                .frame(height: 200)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .padding()

                // Undo / Clear row
                HStack(spacing: 16) {
                    Button {
                        undoManager_?.undo()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!(undoManager_?.canUndo ?? false))

                    Button {
                        canvasView.drawing = PKDrawing()
                    } label: {
                        Label("Clear All", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.red)
                }
                .padding(.horizontal)

                Spacer().frame(height: 12)

                Button {
                    let image = extractSignature()
                    if let image {
                        onSign(image, canvasView.drawing)
                    }
                    dismiss()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func extractSignature() -> UIImage? {
        let drawing = canvasView.drawing
        guard !drawing.bounds.isEmpty else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -10, dy: -10)
        return drawing.image(from: bounds, scale: canvasView.traitCollection.displayScale)
    }
}

struct SignatureCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let existingDrawing: PKDrawing?
    let onUndoManager: (UndoManager?) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.backgroundColor = .clear

        // Restore previous drawing if "Change Signature" was tapped
        if let existingDrawing {
            canvasView.drawing = existingDrawing
        }

        // Expose the undoManager after a short delay so it's ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onUndoManager(canvasView.undoManager)
        }

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
