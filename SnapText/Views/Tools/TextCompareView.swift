import SwiftUI

struct TextCompareView: View {
    @State private var textA = ""
    @State private var textB = ""
    @State private var diffResult: [DiffLine] = []
    @State private var showResult = false

    var body: some View {
        if showResult {
            resultView
        } else {
            inputView
        }
    }

    private var inputView: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original Text")
                        .font(.headline)
                    TextEditor(text: $textA)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Modified Text")
                        .font(.headline)
                    TextEditor(text: $textB)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal)

                Button {
                    compare()
                } label: {
                    Label("Compare", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .disabled(textA.isEmpty && textB.isEmpty)
            }
            .padding(.vertical)
        }
        .navigationTitle("Compare Texts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var resultView: some View {
        VStack(spacing: 0) {
            // Stats
            let added = diffResult.filter { $0.type == .added }.count
            let removed = diffResult.filter { $0.type == .removed }.count
            let unchanged = diffResult.filter { $0.type == .same }.count

            HStack(spacing: 16) {
                statBadge(label: "Unchanged", count: unchanged, color: .secondary)
                statBadge(label: "Added", count: added, color: .green)
                statBadge(label: "Removed", count: removed, color: .red)
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(diffResult) { line in
                        HStack(spacing: 8) {
                            Text(line.type.prefix)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(line.type.color)
                                .frame(width: 16)

                            Text(line.text)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(line.type == .same ? .primary : line.type.color)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(line.type.bgColor)
                    }
                }
            }

            Button {
                showResult = false
            } label: {
                Label("Edit Texts", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding()
        }
        .navigationTitle("Differences")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statBadge(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func compare() {
        let linesA = textA.components(separatedBy: "\n")
        let linesB = textB.components(separatedBy: "\n")
        diffResult = computeDiff(old: linesA, new: linesB)
        showResult = true
    }

    // Simple LCS-based diff
    private func computeDiff(old: [String], new: [String]) -> [DiffLine] {
        let m = old.count, n = new.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                if old[i - 1] == new[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        // Backtrack
        var result: [DiffLine] = []
        var i = m, j = n
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && old[i - 1] == new[j - 1] {
                result.append(DiffLine(text: old[i - 1], type: .same))
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
                result.append(DiffLine(text: new[j - 1], type: .added))
                j -= 1
            } else {
                result.append(DiffLine(text: old[i - 1], type: .removed))
                i -= 1
            }
        }
        return result.reversed()
    }
}

private struct DiffLine: Identifiable {
    let id = UUID()
    let text: String
    let type: DiffType

    enum DiffType {
        case same, added, removed

        var prefix: String {
            switch self {
            case .same: return " "
            case .added: return "+"
            case .removed: return "-"
            }
        }

        var color: Color {
            switch self {
            case .same: return .primary
            case .added: return .green
            case .removed: return .red
            }
        }

        var bgColor: Color {
            switch self {
            case .same: return .clear
            case .added: return .green.opacity(0.08)
            case .removed: return .red.opacity(0.08)
            }
        }
    }
}
