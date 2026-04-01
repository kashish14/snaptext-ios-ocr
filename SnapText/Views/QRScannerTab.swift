import SwiftUI
import AVFoundation
import Vision

struct QRScannerTab: View {
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var scannedResult: QRScanResult?
    @State private var errorMessage: String?
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("QR Scanner")
                        .font(.title2.bold())
                    Text("Scan QR codes from camera or gallery")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if isProcessing {
                    ProgressView("Scanning...")
                        .padding()
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }

            Spacer()

            HStack(spacing: 20) {
                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    showGallery = true
                } label: {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                processQRFromImage(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showGallery) {
            ImagePicker { image in
                processQRFromImage(image)
            }
        }
        .sheet(item: $scannedResult) { result in
            QRResultSheet(result: result)
        }
    }

    private func processQRFromImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil

        // Normalize image orientation for Vision framework
        let fixedImage = image.fixedOrientation()
        guard let cgImage = fixedImage.cgImage else {
            errorMessage = "Could not process image."
            isProcessing = false
            return
        }

        Task.detached {
            do {
                let request = VNDetectBarcodesRequest()
                request.symbologies = [.qr, .aztec, .dataMatrix, .codabar, .code128, .code39, .code93, .ean8, .ean13, .upce, .itf14, .pdf417]

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])

                let results = request.results ?? []

                await MainActor.run {
                    isProcessing = false
                    if let first = results.first, let payload = first.payloadStringValue {
                        scannedResult = QRScanResult(rawValue: payload)
                    } else {
                        errorMessage = "No QR code found in image. Try a clearer photo."
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Scan failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - QR Result Model

struct QRScanResult: Identifiable {
    let id = UUID()
    let rawValue: String

    var type: QRType {
        if rawValue.hasPrefix("WIFI:") { return .wifi }
        if rawValue.hasPrefix("BEGIN:VCARD") { return .vCard }
        if rawValue.hasPrefix("upi://") { return .upi }
        if rawValue.hasPrefix("tel:") { return .phone }
        if rawValue.hasPrefix("mailto:") { return .email }
        if rawValue.lowercased().hasPrefix("http://") || rawValue.lowercased().hasPrefix("https://") { return .url }
        if URL(string: rawValue)?.scheme != nil { return .url }
        return .text
    }

    enum QRType: String {
        case url, wifi, vCard, upi, phone, email, text
    }

    var displayTitle: String {
        switch type {
        case .url: return "Website"
        case .wifi: return "Wifi Network"
        case .vCard: return "Contact"
        case .upi: return "UPI Payment"
        case .phone: return "Phone Number"
        case .email: return "Email"
        case .text: return "Text"
        }
    }

    var icon: String {
        switch type {
        case .url: return "safari.fill"
        case .wifi: return "wifi"
        case .vCard: return "person.crop.rectangle.fill"
        case .upi: return "indianrupeesign.circle.fill"
        case .phone: return "phone.fill"
        case .email: return "envelope.fill"
        case .text: return "doc.text"
        }
    }

    // Parse wifi: WIFI:T:WPA;S:MyNetwork;P:MyPassword;;
    var wifiSSID: String? {
        guard type == .wifi else { return nil }
        return parseWifiField("S")
    }

    var wifiPassword: String? {
        guard type == .wifi else { return nil }
        return parseWifiField("P")
    }

    private func parseWifiField(_ key: String) -> String? {
        let pattern = "\(key):([^;]*)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: rawValue, range: NSRange(rawValue.startIndex..., in: rawValue)),
              let range = Range(match.range(at: 1), in: rawValue) else { return nil }
        return String(rawValue[range])
    }
}

// MARK: - Image Orientation Fix

extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}

// MARK: - QR Result Sheet

private struct QRResultSheet: View {
    let result: QRScanResult
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: result.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                Text(result.displayTitle)
                    .font(.title2.bold())

                // Content
                VStack(alignment: .leading, spacing: 12) {
                    if result.type == .wifi {
                        wifiContent
                    } else {
                        Text(result.rawValue)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)

                // Actions
                VStack(spacing: 12) {
                    actionButton

                    Button {
                        ClipboardManager.shared.copy(result.rawValue, source: "QR Scan")
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch result.type {
        case .url:
            Button {
                if let url = URL(string: result.rawValue) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open in Safari", systemImage: "safari.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .phone:
            Button {
                let number = result.rawValue.replacingOccurrences(of: "tel:", with: "")
                if let url = URL(string: "tel:\(number)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Call", systemImage: "phone.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .email:
            Button {
                if let url = URL(string: result.rawValue) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Send Email", systemImage: "envelope.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .upi:
            Button {
                if let url = URL(string: result.rawValue) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Payment", systemImage: "indianrupeesign.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .wifi:
            if let password = result.wifiPassword {
                Button {
                    UIPasteboard.general.string = password
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label("Copy Password", systemImage: "key.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

        case .vCard, .text:
            EmptyView()
        }
    }

    private var wifiContent: some View {
        VStack(spacing: 12) {
            if let ssid = result.wifiSSID {
                HStack {
                    Text("Network").foregroundStyle(.secondary)
                    Spacer()
                    Text(ssid).bold()
                }
            }
            if let password = result.wifiPassword {
                HStack {
                    Text("Password").foregroundStyle(.secondary)
                    Spacer()
                    Text(password).bold()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
