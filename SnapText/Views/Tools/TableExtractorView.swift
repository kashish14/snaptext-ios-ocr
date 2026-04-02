import SwiftUI

struct TableExtractorView: View {
    @Environment(\.toolContext) private var toolContext
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var isProcessing = false
    @State private var tableRows: [[String]] = []
    @State private var rawText = ""
    @State private var errorMessage: String?
    @State private var copied = false
    @State private var didApplyContext = false

    private let ocrService = OCRService()

    var body: some View {
        VStack(spacing: 0) {
            if tableRows.isEmpty && !isProcessing {
                emptyState
            } else if isProcessing {
                Spacer()
                ProgressView("Extracting table...")
                Spacer()
            } else {
                tableResultView
            }
        }
        .navigationTitle("Table Extractor")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !didApplyContext, let img = toolContext.image, img.size.width > 0 {
                didApplyContext = true
                Task { await extractTable(from: img) }
            } else if !didApplyContext, let text = toolContext.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                didApplyContext = true
                rawText = text
                let rows = parseTable(from: text)
                if rows.isEmpty {
                    errorMessage = "No table structure detected."
                } else {
                    tableRows = rows
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                Task { await extractTable(from: image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showGallery) {
            ImagePicker { image in
                Task { await extractTable(from: image) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "tablecells")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                VStack(spacing: 8) {
                    Text("Table Extractor")
                        .font(.title2.bold())
                    Text("Scan a table or grid from an image and export as CSV")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if let error = errorMessage {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            Spacer()

            HStack(spacing: 12) {
                Button { showCamera = true } label: {
                    Label("Camera", systemImage: "camera.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)

                Button { showGallery = true } label: {
                    Label("Gallery", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
            }
            .padding(.horizontal).padding(.bottom, 16)
        }
    }

    private var tableResultView: some View {
        VStack(spacing: 12) {
            Text("\(tableRows.count) rows detected")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            // Table display
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(tableRows.indices, id: \.self) { rowIndex in
                        HStack(spacing: 0) {
                            ForEach(tableRows[rowIndex].indices, id: \.self) { colIndex in
                                Text(tableRows[rowIndex][colIndex])
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(8)
                                    .frame(minWidth: 80, alignment: .leading)
                                    .background(rowIndex == 0 ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground))
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color(.separator), lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    let csv = generateCSV()
                    ClipboardManager.shared.copy(csv, source: "Table")
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Label(copied ? "Copied!" : "Copy as CSV", systemImage: copied ? "checkmark" : "doc.on.doc.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)

                ShareLink(item: generateCSV()) {
                    Label("Share CSV", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)

                HStack(spacing: 12) {
                    Button { showGallery = true } label: {
                        Label("Re-scan", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large)

                    Button(role: .destructive) {
                        tableRows = []
                        rawText = ""
                    } label: {
                        Label("Clear", systemImage: "trash").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private func extractTable(from image: UIImage) async {
        isProcessing = true
        errorMessage = nil

        do {
            let text = try await ocrService.recognizeText(in: image, mode: .accurate)
            rawText = text
            let rows = parseTable(from: text)

            await MainActor.run {
                if rows.isEmpty {
                    errorMessage = "No table structure detected."
                } else {
                    tableRows = rows
                }
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not extract text."
                isProcessing = false
            }
        }
    }

    private func parseTable(from text: String) -> [[String]] {
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return [] }

        // Try tab-separated first
        let tabRows = lines.map { $0.components(separatedBy: "\t") }
        if tabRows.allSatisfy({ $0.count > 1 }) {
            return normalizeColumns(tabRows)
        }

        // Try pipe-separated (| col | col |)
        let pipeRows = lines.compactMap { line -> [String]? in
            guard line.contains("|") else { return nil }
            let cols = line.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.allSatisfy({ $0 == "-" || $0 == "=" }) }
            return cols.isEmpty ? nil : cols
        }
        if pipeRows.count >= 2 {
            return normalizeColumns(pipeRows)
        }

        // Try multiple-space-separated (columns aligned with spaces)
        let spaceRows = lines.map { line -> [String] in
            let parts = line.components(separatedBy: "  ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return parts.count >= 2 ? parts : [line]
        }
        let multiColRows = spaceRows.filter { $0.count >= 2 }
        if multiColRows.count >= 2 {
            return normalizeColumns(spaceRows)
        }

        // Fallback: treat each line as a single-column row
        return lines.map { [$0] }
    }

    private func normalizeColumns(_ rows: [[String]]) -> [[String]] {
        let maxCols = rows.map { $0.count }.max() ?? 1
        return rows.map { row in
            var r = row
            while r.count < maxCols { r.append("") }
            return r
        }
    }

    private func generateCSV() -> String {
        tableRows.map { row in
            row.map { cell in
                let escaped = cell.replacingOccurrences(of: "\"", with: "\"\"")
                return cell.contains(",") || cell.contains("\"") || cell.contains("\n") ? "\"\(escaped)\"" : cell
            }.joined(separator: ",")
        }.joined(separator: "\n")
    }
}
