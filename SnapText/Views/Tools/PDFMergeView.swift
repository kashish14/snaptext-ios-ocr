import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct PDFMergeView: View {
    @State private var pdfURLs: [URL] = []
    @State private var mergedPDFURL: URL?
    @State private var showFilePicker = false
    @State private var errorMessage: String?
    @State private var isMerging = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if pdfURLs.isEmpty {
                    emptyState
                } else {
                    fileListSection
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Merge PDFs")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    // Copy to temp so we can access later
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.removeItem(at: tempURL)
                    try? FileManager.default.copyItem(at: url, to: tempURL)
                    url.stopAccessingSecurityScopedResource()
                    if !pdfURLs.contains(where: { $0.lastPathComponent == tempURL.lastPathComponent }) {
                        pdfURLs.append(tempURL)
                    }
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 80)
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.08))
                        .frame(width: 120, height: 120)
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.red)
                }
                VStack(spacing: 8) {
                    Text("Merge PDFs")
                        .font(.title2.bold())
                    Text("Combine multiple PDF files into one document")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            Spacer(minLength: 80)
            Button {
                showFilePicker = true
            } label: {
                Label("Select PDFs", systemImage: "folder")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private var fileListSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("PDF Files (\(pdfURLs.count))")
                        .font(.headline)
                    Spacer()
                    Button { showFilePicker = true } label: {
                        Label("Add More", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                    }
                }
                .padding(.horizontal)

                ForEach(pdfURLs.indices, id: \.self) { index in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.red)
                            .frame(width: 36, height: 36)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pdfURLs[index].lastPathComponent)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            if let size = fileSize(pdfURLs[index]) {
                                Text(size)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        // Move up/down
                        if index > 0 {
                            Button { pdfURLs.swapAt(index, index - 1) } label: {
                                Image(systemName: "arrow.up")
                                    .font(.caption)
                            }
                        }
                        if index < pdfURLs.count - 1 {
                            Button { pdfURLs.swapAt(index, index + 1) } label: {
                                Image(systemName: "arrow.down")
                                    .font(.caption)
                            }
                        }

                        Button {
                            pdfURLs.remove(at: index)
                            mergedPDFURL = nil
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Actions
            VStack(spacing: 10) {
                Button {
                    mergePDFs()
                } label: {
                    if isMerging {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Label("Merge \(pdfURLs.count) PDFs", systemImage: "doc.on.doc")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(pdfURLs.count < 2 || isMerging)

                if let url = mergedPDFURL {
                    ShareLink(item: url) {
                        Label("Share Merged PDF", systemImage: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Merged successfully!")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    pdfURLs.removeAll()
                    mergedPDFURL = nil
                    errorMessage = nil
                } label: {
                    Label("Clear All", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
            }
            .padding(.horizontal)
        }
    }

    private func mergePDFs() {
        isMerging = true
        errorMessage = nil
        mergedPDFURL = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let mergedDoc = PDFDocument()
            var pageIndex = 0

            for url in pdfURLs {
                guard let doc = PDFDocument(url: url) else { continue }
                for i in 0..<doc.pageCount {
                    if let page = doc.page(at: i) {
                        mergedDoc.insert(page, at: pageIndex)
                        pageIndex += 1
                    }
                }
            }

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("SnapText_Merged_\(Int(Date().timeIntervalSince1970)).pdf")

            let success = mergedDoc.write(to: outputURL)

            DispatchQueue.main.async {
                isMerging = false
                if success {
                    mergedPDFURL = outputURL
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    errorMessage = "Failed to merge PDFs"
                }
            }
        }
    }

    private func fileSize(_ url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
