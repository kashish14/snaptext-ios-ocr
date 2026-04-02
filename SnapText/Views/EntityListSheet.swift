import SwiftUI
import EventKitUI
import NetworkExtension

struct EntityListSheet: View {
    let title: String
    let entities: [DetectedEntity]
    @Environment(\.dismiss) private var dismiss
    @State private var copiedValue: String?
    @State private var calendarEntity: DetectedEntity?
    @State private var showCalendarDenied = false
    @State private var contactEntity: DetectedEntity?

    var body: some View {
        NavigationStack {
            List {
                ForEach(entities) { entity in
                    entityRow(entity)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $calendarEntity) { entity in
                let parsedDate = CalendarManager.shared.parseDate(from: entity)
                let smartTitle = CalendarManager.shared.smartTitle(from: entity.value)
                CalendarEventEditor(title: smartTitle, date: parsedDate)
            }
            .alert("Calendar Access Denied", isPresented: $showCalendarDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please allow calendar access in Settings to add events.")
            }
            .sheet(item: $contactEntity) { entity in
                let phone = entity.type == .phoneNumber ? entity.value : nil
                let email = entity.type == .email ? entity.value : nil
                ContactCreatorView(phoneNumber: phone, email: email)
            }
        }
    }

    // MARK: - Row

    private func entityRow(_ entity: DetectedEntity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: entity.iconName)
                    .font(.title3)
                    .foregroundStyle(iconColor(for: entity.type))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entity.value)
                        .font(.body)
                    if let secondary = entity.secondaryValue, !secondary.isEmpty {
                        Text(secondaryLabel(for: entity.type, value: secondary))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                copyButton(entity.value)
                actionButton(for: entity)
            }

            // Secondary copy for wifi password
            if entity.type == .wifi, let password = entity.secondaryValue, !password.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        copyToClipboard(password)
                    } label: {
                        Label("Copy Password", systemImage: "key.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Copy

    private func copyButton(_ value: String) -> some View {
        Button {
            copyToClipboard(value)
        } label: {
            Image(systemName: copiedValue == value ? "checkmark" : "doc.on.doc")
                .font(.subheadline)
                .foregroundStyle(copiedValue == value ? .green : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func copyToClipboard(_ value: String) {
        ClipboardManager.shared.copy(value, source: "Detection")
        copiedValue = value
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedValue == value { copiedValue = nil }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButton(for entity: DetectedEntity) -> some View {
        switch entity.type {
        case .phoneNumber:
            Button { contactEntity = entity } label: {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            openURLButton(
                urlString: "tel:\(entity.value.filter { $0.isNumber || $0 == "+" })",
                icon: "phone.circle.fill",
                color: .green
            )

        case .address:
            openURLButton(
                urlString: "maps://?q=\(entity.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                icon: "map.circle.fill",
                color: .blue
            )

        case .email:
            Button { contactEntity = entity } label: {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            openURLButton(
                urlString: "mailto:\(entity.value)",
                icon: "envelope.circle.fill",
                color: .purple
            )

        case .url:
            openURLButton(
                urlString: entity.value,
                icon: "safari.fill",
                color: .orange
            )

        case .date:
            Button {
                Task {
                    let granted = await CalendarManager.shared.requestAccess()
                    if granted {
                        calendarEntity = entity
                    } else {
                        showCalendarDenied = true
                    }
                }
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)

        case .upiId:
            openURLButton(
                urlString: "upi://pay?pa=\(entity.value)",
                icon: "indianrupeesign.circle.fill",
                color: .green
            )

        case .trackingNumber:
            openURLButton(
                urlString: trackingURL(for: entity.value),
                icon: "shippingbox.circle.fill",
                color: .indigo
            )

        case .flightNumber:
            openURLButton(
                urlString: "https://www.google.com/search?q=flight+\(entity.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")+status",
                icon: "airplane.circle.fill",
                color: .blue
            )

        case .coordinates:
            let parts = entity.value.components(separatedBy: CharacterSet(charactersIn: ",/"))
            let lat = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
            let lon = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            openURLButton(
                urlString: "maps://?ll=\(lat),\(lon)",
                icon: "map.circle.fill",
                color: .blue
            )

        case .socialHandle:
            let handle = entity.value.hasPrefix("@") ? String(entity.value.dropFirst()) : entity.value
            openURLButton(
                urlString: "https://www.google.com/search?q=\(handle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")+social+profile",
                icon: "person.circle.fill",
                color: .pink
            )

        case .wifi:
            if let ssid = entity.value.isEmpty ? nil : entity.value,
               ssid != "Wifi Password" {
                Button {
                    connectToWifi(ssid: ssid, password: entity.secondaryValue)
                } label: {
                    Image(systemName: "wifi.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
            }

        case .ifscCode, .panNumber, .aadhaarNumber, .gstNumber,
             .orderId, .ipAddress, .bankAccount, .currency:
            EmptyView()
        }
    }

    private func openURLButton(urlString: String, icon: String, color: Color) -> some View {
        Button {
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        } label: {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func iconColor(for type: DetectedEntity.EntityType) -> Color {
        switch type {
        case .phoneNumber: return .green
        case .address, .coordinates: return .blue
        case .email: return .purple
        case .url: return .orange
        case .date: return .red
        case .upiId: return .green
        case .trackingNumber, .orderId: return .indigo
        case .wifi: return .cyan
        case .flightNumber: return .blue
        case .currency, .bankAccount: return .green
        case .socialHandle: return .pink
        case .ifscCode: return .brown
        case .panNumber, .aadhaarNumber, .gstNumber: return .gray
        case .ipAddress: return .teal
        }
    }

    private func secondaryLabel(for type: DetectedEntity.EntityType, value: String) -> String {
        switch type {
        case .wifi: return "Password: \(value)"
        default: return value
        }
    }

    private func trackingURL(for number: String) -> String {
        let encoded = number.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? number
        let digits = number.filter { $0.isNumber }

        // Blue Dart: 8-11 digit AWB
        if digits.count >= 8 && digits.count <= 11 {
            return "https://www.bluedart.com/tracking?handler=tref&numbers=\(encoded)"
        }
        // Delhivery: 12-14 digits
        if digits.count >= 12 && digits.count <= 14 {
            return "https://www.delhivery.com/track/package/\(encoded)"
        }
        // India Post: EE123456789IN format
        if number.count == 13, number.hasPrefix("E") || number.hasPrefix("R") || number.hasPrefix("C") {
            return "https://www.indiapost.gov.in/_layouts/15/dop.portal.tracking/trackconsignment.aspx?id=\(encoded)"
        }
        // UPS: 1Z format
        if number.hasPrefix("1Z") {
            return "https://www.ups.com/track?tracknum=\(encoded)"
        }
        // FedEx: 20-22 digits
        if digits.count >= 20 {
            return "https://www.fedex.com/fedextrack/?trknbr=\(encoded)"
        }
        // Default: use a universal tracker
        return "https://parcelsapp.com/en/tracking/\(encoded)"
    }

    private func connectToWifi(ssid: String, password: String?) {
        let config: NEHotspotConfiguration
        if let password, !password.isEmpty {
            config = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        } else {
            config = NEHotspotConfiguration(ssid: ssid)
        }
        config.joinOnce = false

        NEHotspotConfigurationManager.shared.apply(config) { error in
            if let error {
                // Error code 13 = "already associated" = success
                if (error as NSError).code == 13 {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}
