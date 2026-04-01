import SwiftUI

struct BusinessCardScannerView: View {
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var isProcessing = false
    @State private var cardInfo: CardInfo?
    @State private var showContactCreator = false
    @State private var errorMessage: String?

    private let ocrService = OCRService()
    private let smartDetector = SmartDetector()

    var body: some View {
        VStack(spacing: 0) {
            if let info = cardInfo {
                cardResultView(info)
            } else {
                emptyState
            }
        }
        .navigationTitle("Business Card")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                Task { await scanCard(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showGallery) {
            ImagePicker { image in
                Task { await scanCard(image) }
            }
        }
        .sheet(isPresented: $showContactCreator) {
            if let info = cardInfo {
                ContactCreatorView(
                    phoneNumber: info.phones.first,
                    email: info.emails.first
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                VStack(spacing: 8) {
                    Text("Business Card Scanner")
                        .font(.title2.bold())
                    Text("Scan a card to extract name, phone, email, and company")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if isProcessing {
                    ProgressView("Scanning...")
                }
                if let error = errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            Spacer()

            HStack(spacing: 12) {
                Button { showCamera = true } label: {
                    Label("Camera", systemImage: "camera.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button { showGallery = true } label: {
                    Label("Gallery", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private func cardResultView(_ info: CardInfo) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Card image
                if let img = info.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                }

                // Extracted fields
                VStack(spacing: 0) {
                    if let name = info.name {
                        cardField(icon: "person.fill", label: "Name", value: name)
                    }
                    if let company = info.company {
                        cardField(icon: "building.2.fill", label: "Company", value: company)
                    }
                    if let title = info.jobTitle {
                        cardField(icon: "briefcase.fill", label: "Title", value: title)
                    }
                    ForEach(info.phones, id: \.self) { phone in
                        cardField(icon: "phone.fill", label: "Phone", value: phone)
                    }
                    ForEach(info.emails, id: \.self) { email in
                        cardField(icon: "envelope.fill", label: "Email", value: email)
                    }
                    ForEach(info.urls, id: \.self) { url in
                        cardField(icon: "globe", label: "Website", value: url)
                    }
                    if let address = info.address {
                        cardField(icon: "map.fill", label: "Address", value: address)
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Actions
                VStack(spacing: 12) {
                    Button {
                        showContactCreator = true
                    } label: {
                        Label("Save as Contact", systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        let allText = info.allFields.joined(separator: "\n")
                        ClipboardManager.shared.copy(allText, source: "Card")
                    } label: {
                        Label("Copy All", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    HStack(spacing: 12) {
                        Button { showCamera = true } label: {
                            Label("Re-scan", systemImage: "camera.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button(role: .destructive) { cardInfo = nil } label: {
                            Label("Clear", systemImage: "trash").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .padding(.vertical)
        }
    }

    private func cardField(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .textSelection(.enabled)
            }

            Spacer()

            Button {
                ClipboardManager.shared.copy(value, source: "Card")
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func scanCard(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil

        do {
            let text = try await ocrService.recognizeText(in: image, mode: .accurate)
            let entities = smartDetector.detect(in: text)
            let info = extractCardInfo(text: text, entities: entities, image: image)
            await MainActor.run {
                cardInfo = info
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not scan card."
                isProcessing = false
            }
        }
    }

    private func extractCardInfo(text: String, entities: [DetectedEntity], image: UIImage) -> CardInfo {
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        let phones = entities.filter { $0.type == .phoneNumber }.map { $0.value }
        let emails = entities.filter { $0.type == .email }.map { $0.value }
        let urls = entities.filter { $0.type == .url }.map { $0.value }
        let addresses = entities.filter { $0.type == .address }.map { $0.value }

        // Heuristic: name is usually the first or most prominent line that isn't a company or phone/email
        let knownValues = Set(phones + emails + urls + addresses)
        let candidateLines = lines.filter { line in
            !knownValues.contains(where: { line.contains($0) }) && line.count >= 3
        }

        // Name: typically short, 2-4 words, first such line
        let name = candidateLines.first { line in
            let words = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            return words.count >= 2 && words.count <= 5 && !line.contains("@") && !line.contains("www")
        }

        // Company: often the next line after name, or a line with common suffixes
        let companySuffixes = ["Ltd", "LLC", "Inc", "Corp", "Pvt", "LLP", "Co.", "Group", "Technologies", "Solutions", "Services", "Consulting"]
        let company = candidateLines.first { line in
            line != name && companySuffixes.contains(where: { line.localizedCaseInsensitiveContains($0) })
        } ?? candidateLines.first { $0 != name && $0.count > 3 }

        // Job title: line with common title keywords
        let titleKeywords = ["Manager", "Director", "Engineer", "Developer", "CEO", "CTO", "VP", "Head", "Lead", "Founder", "Analyst", "Designer", "Consultant", "Executive", "Officer", "President"]
        let jobTitle = candidateLines.first { line in
            line != name && line != company && titleKeywords.contains(where: { line.localizedCaseInsensitiveContains($0) })
        }

        return CardInfo(
            name: name,
            company: company,
            jobTitle: jobTitle,
            phones: phones,
            emails: emails,
            urls: urls,
            address: addresses.first,
            image: image
        )
    }
}

private struct CardInfo {
    let name: String?
    let company: String?
    let jobTitle: String?
    let phones: [String]
    let emails: [String]
    let urls: [String]
    let address: String?
    let image: UIImage?

    var allFields: [String] {
        var fields: [String] = []
        if let n = name { fields.append("Name: \(n)") }
        if let c = company { fields.append("Company: \(c)") }
        if let t = jobTitle { fields.append("Title: \(t)") }
        phones.forEach { fields.append("Phone: \($0)") }
        emails.forEach { fields.append("Email: \($0)") }
        urls.forEach { fields.append("Web: \($0)") }
        if let a = address { fields.append("Address: \(a)") }
        return fields
    }
}
