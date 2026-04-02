import SwiftUI

struct IntelligentResultView: View {
    let result: ScanResult
    let onDismiss: () -> Void

    @State private var rankedResult: ActionPriorityEngine.RankedResult?
    @State private var showCopiedToast = false
    @State private var showDoMore = false
    @State private var showEntitySheet: DetectedEntity.EntityType?
    @State private var showFullscreenImage = false
    @State private var showToolView: AnyView?
    @State private var showToolSheet = false
    @State private var showBillSplit = false
    @State private var billSplitCount = 2
    @State private var billManualAmount = ""

    private let engine = ActionPriorityEngine()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero image (only if we have a real image)
                    if result.image.size.width > 0 {
                        heroImage
                    }

                    VStack(spacing: 20) {
                        // A. Understood — entity chips with direct actions
                        if !result.entities.isEmpty {
                            understoodSection
                        }

                        // B. Extracted — clean text
                        extractedTextSection

                        // B2. Bill Split — when amounts detected
                        if hasCurrencyOrAmounts {
                            billSplitSection
                        }

                        // C. Quick Actions — top 3–5 scored
                        if let ranked = rankedResult, !ranked.quickActions.isEmpty {
                            quickActionsSection(ranked.quickActions)
                        }

                        // D. Do More button
                        doMoreButton
                    }
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { onDismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    copiedToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(item: $showEntitySheet) { type in
                EntityListSheet(
                    title: EntityCategoryHelper.sheetTitle(for: type),
                    entities: result.entities.filter { $0.type == type }
                )
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showFullscreenImage) {
                FullscreenImageViewer(image: result.image)
            }
            .sheet(isPresented: $showDoMore) {
                doMoreSheet
            }
            .sheet(isPresented: $showToolSheet) {
                if let toolView = showToolView {
                    NavigationStack {
                        toolView
                            .environment(\.toolContext, ToolContext(
                                image: result.image.size.width > 0 ? result.image : nil,
                                text: result.text
                            ))
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("Close") { showToolSheet = false }
                                }
                            }
                    }
                }
            }
            .onAppear {
                rankedResult = engine.rank(
                    text: result.text,
                    image: result.image.size.width > 0 ? result.image : nil,
                    entities: result.entities
                )
            }
        }
    }

    // MARK: - A. Hero Image

    private var heroImage: some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: result.image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .frame(maxWidth: .infinity)
                .clipped()
                .onTapGesture { showFullscreenImage = true }

            LinearGradient(
                colors: [.clear, Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 50)

            HStack {
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption2.bold())
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - A. Understood (Entities)

    private var understoodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text("Understood")
                    .font(.headline)
            }
            .padding(.horizontal)

            // Entity action chips — inline, 1-tap
            if let ranked = rankedResult, !ranked.entityActions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ranked.entityActions) { action in
                            Button {
                                action.directAction?()
                                UserBehaviorTracker.shared.recordAction(action.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: action.icon)
                                        .font(.caption2.weight(.semibold))
                                    Text(action.title)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(action.color.opacity(0.15))
                                .foregroundStyle(action.color)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(action.color.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Category badges (tap to see full list)
            let categories = EntityCategoryHelper.categories(from: result.entities)
            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(categories, id: \.type) { cat in
                            Button {
                                showEntitySheet = cat.type
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.icon)
                                        .font(.caption2)
                                    Text("\(cat.count)")
                                        .font(.caption2.bold())
                                    Text(cat.label)
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - B. Extracted Text

    private var extractedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.blue)
                Text("Extracted")
                    .font(.headline)
                Spacer()
                Button {
                    ClipboardManager.shared.copy(result.text, source: "Scan")
                    showCopiedFeedback()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                ShareLink(item: cleanText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.horizontal)

            SelectableTextView(text: result.text)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(4)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 3, y: 2)
                .padding(.horizontal)
        }
    }

    // MARK: - C. Quick Actions

    private func quickActionsSection(_ actions: [QuickAction]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                Text("Quick Actions")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(actions) { action in
                    quickActionRow(action)
                }
            }
            .padding(.horizontal)
        }
    }

    private func quickActionRow(_ action: QuickAction) -> some View {
        Button {
            handleAction(action)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(action.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                Text(action.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: action.isDirectAction ? "checkmark.circle" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - D. Do More

    private var doMoreButton: some View {
        Button {
            showDoMore = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.subheadline)
                Text("All Tools")
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var doMoreSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    doMoreGroup("Document", category: .document)
                    doMoreGroup("Image", category: .image)
                    doMoreGroup("Text", category: .text)
                    doMoreGroup("Utilities", category: .utility)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("All Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showDoMore = false }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func doMoreGroup(_ title: String, category: QuickAction.ActionCategory) -> some View {
        let actions = allActionsForCategory(category)
        guard !actions.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(actions) { action in
                        Button {
                            showDoMore = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                handleAction(action)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: action.icon)
                                    .font(.title3.weight(.medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(action.color.gradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 11))

                                Text(action.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        )
    }

    private func allActionsForCategory(_ category: QuickAction.ActionCategory) -> [QuickAction] {
        guard let ranked = rankedResult else { return [] }
        let all = ranked.quickActions + ranked.doMoreActions
        return all.filter { $0.category == category && $0.toolDestination != nil }
    }

    // MARK: - Action Handling

    private func handleAction(_ action: QuickAction) {
        UserBehaviorTracker.shared.recordAction(action.id)

        if let directAction = action.directAction {
            directAction()
            if action.id == "copy_text" {
                showCopiedFeedback()
            }
        } else if let destination = action.toolDestination {
            showToolView = destination()
            showToolSheet = true
        }
    }

    // MARK: - Toast

    private var copiedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text("Copied!")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(Color.green.gradient)
                .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
        )
        .padding(.bottom, 30)
    }

    private func showCopiedFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(duration: 0.3)) { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(duration: 0.3)) { showCopiedToast = false }
        }
    }

    // MARK: - Bill Split

    private var hasCurrencyOrAmounts: Bool {
        result.entities.contains(where: { $0.type == .currency }) ||
        result.text.lowercased().contains("total") ||
        result.text.lowercased().contains("amount") ||
        result.text.contains("₹") || result.text.contains("$") ||
        result.text.lowercased().contains("rs")
    }

    private var detectedTotal: Double {
        // Try to find the largest currency entity value
        let currencyEntities = result.entities.filter { $0.type == .currency }
        var largest: Double = 0
        for entity in currencyEntities {
            let cleaned = entity.value.replacingOccurrences(of: ",", with: "")
            let pattern = try! NSRegularExpression(pattern: #"[\d]+\.?\d{0,2}"#)
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            if let match = pattern.matches(in: cleaned, range: range).last,
               let r = Range(match.range, in: cleaned),
               let num = Double(cleaned[r]) {
                if num > largest { largest = num }
            }
        }
        return largest
    }

    private var billSplitAmount: Double {
        let detected = detectedTotal
        if detected > 0 { return detected }
        return Double(billManualAmount) ?? 0
    }

    private var billSplitSection: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation { showBillSplit.toggle() }
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.blue)
                    Text("Split Bill")
                        .font(.headline)
                    Spacer()
                    Image(systemName: showBillSplit ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
            .buttonStyle(.plain)

            if showBillSplit {
                VStack(spacing: 12) {
                    if detectedTotal > 0 {
                        HStack {
                            Text("Detected Total")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "₹%.2f", detectedTotal))
                                .font(.headline.bold())
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enter Total Amount")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("e.g. 1250.00", text: $billManualAmount)
                                .keyboardType(.decimalPad)
                                .padding(10)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    HStack(spacing: 16) {
                        Text("People")
                            .font(.subheadline)
                        Spacer()
                        HStack(spacing: 0) {
                            Button {
                                if billSplitCount > 2 { billSplitCount -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(billSplitCount > 2 ? .blue : .gray)
                            }
                            .disabled(billSplitCount <= 2)

                            Text("\(billSplitCount)")
                                .font(.title3.bold().monospaced())
                                .frame(width: 44)

                            Button {
                                if billSplitCount < 20 { billSplitCount += 1 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    if billSplitAmount > 0 {
                        Divider()

                        HStack {
                            Text("Per person")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "₹%.2f", billSplitAmount / Double(billSplitCount)))
                                .font(.title2.bold())
                                .foregroundStyle(.green)
                        }

                        Button {
                            let text = "Bill split: ₹\(String(format: "%.2f", billSplitAmount)) ÷ \(billSplitCount) = ₹\(String(format: "%.2f", billSplitAmount / Double(billSplitCount))) per person"
                            ClipboardManager.shared.copy(text, source: "Bill Split")
                            showCopiedFeedback()
                        } label: {
                            Label("Copy Split", systemImage: "doc.on.doc")
                                .font(.caption.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Clean Text for Sharing

    private var cleanText: String {
        // Merge broken OCR lines, fix spacing for WhatsApp/sharing
        let lines = result.text.components(separatedBy: "\n")
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
            } else if trimmed.first?.isUppercase == true ||
                      trimmed.hasPrefix("-") ||
                      trimmed.hasPrefix("\u{2022}") ||
                      trimmed.first?.isNumber == true {
                cleaned.append(current)
                current = trimmed
            } else {
                current += " " + trimmed
            }
        }
        if !current.isEmpty { cleaned.append(current) }

        // Remove consecutive blank lines
        return cleaned.reduce(into: [String]()) { result, line in
            if line.isEmpty && result.last?.isEmpty == true { return }
            result.append(line)
        }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
