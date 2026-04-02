import SwiftUI

struct ImageToPDFView: View {
    @Environment(\.toolContext) private var toolContext
    @State private var showPicker = false
    @State private var images: [UIImage] = []
    @State private var pdfData: Data?
    @State private var applyBW = false
    @State private var didApplyContext = false

    var body: some View {
        VStack(spacing: 16) {
            if images.isEmpty {
                ContentUnavailableView(
                    "Select Images",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Choose images to combine into a PDF.")
                )
            } else {
                // Image previews
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: applyBW ? image.blackAndWhite() : image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        images.remove(at: index)
                                        pdfData = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white, .red)
                                    }
                                    .padding(4)
                                }
                                .overlay(alignment: .bottomLeading) {
                                    Text("Page \(index + 1)")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                        .padding(6)
                                }
                        }
                    }
                    .padding(.horizontal)
                }

                Text("\(images.count) image\(images.count == 1 ? "" : "s") selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Black & White", isOn: $applyBW)
                    .padding(.horizontal)
                    .onChange(of: applyBW) { pdfData = nil }
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    showPicker = true
                } label: {
                    Label(images.isEmpty ? "Select Images" : "Add More", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if !images.isEmpty {
                    if let data = pdfData {
                        let transferable = PDFTransferable(data: data)
                        ShareLink(item: transferable, preview: SharePreview("Document", image: Image(systemName: "doc.fill"))) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        Button {
                            let source = applyBW ? images.map { $0.blackAndWhite() } : images
                            pdfData = PDFService.renderPDF(from: source)
                        } label: {
                            Label("Generate PDF", systemImage: "doc.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .navigationTitle("Image to PDF")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !didApplyContext, let img = toolContext.image, img.size.width > 0 {
                didApplyContext = true
                images = [img]
            }
        }
        .sheet(isPresented: $showPicker) {
            MultiImagePicker { selected in
                images.append(contentsOf: selected)
                pdfData = nil
            }
        }
    }
}
