import SwiftUI

enum EntityCategoryHelper {

    static let categoryOrder: [(type: DetectedEntity.EntityType, icon: String, label: String, color: Color)] = [
        (.otp,            "lock.shield.fill",              "OTP",          .orange),
        (.phoneNumber,    "phone.fill",                    "Numbers",      .green),
        (.address,        "map.fill",                      "Maps",         .blue),
        (.email,          "envelope.fill",                 "Emails",       .purple),
        (.url,            "link",                          "Links",        .orange),
        (.date,           "calendar",                      "Dates",        .red),
        (.upiId,          "indianrupeesign.circle.fill",   "UPI",          .green),
        (.trackingNumber, "shippingbox.fill",              "Tracking",     .indigo),
        (.wifi,           "wifi",                          "Wifi",         .cyan),
        (.flightNumber,   "airplane",                      "Flights",      .blue),
        (.currency,       "banknote.fill",                 "Amounts",      .green),
        (.socialHandle,   "at",                            "Socials",      .pink),
        (.ifscCode,       "building.columns.fill",         "IFSC",         .brown),
        (.panNumber,      "creditcard.fill",               "PAN",          .gray),
        (.aadhaarNumber,  "person.text.rectangle.fill",    "Aadhaar",      .gray),
        (.gstNumber,      "doc.text.fill",                 "GST",          .gray),
        (.coordinates,    "location.fill",                 "Coordinates",  .blue),
        (.orderId,        "bag.fill",                      "Orders",       .indigo),
        (.ipAddress,      "network",                       "IP Address",   .teal),
        (.bankAccount,    "banknote.fill",                 "Bank A/C",     .green),
    ]

    static func categories(from entities: [DetectedEntity]) -> [(type: DetectedEntity.EntityType, icon: String, label: String, color: Color, count: Int)] {
        let grouped = Dictionary(grouping: entities) { $0.type }
        return categoryOrder.compactMap { type, icon, label, color in
            guard let items = grouped[type], !items.isEmpty else { return nil }
            return (type, icon, label, color, items.count)
        }
    }

    static func sheetTitle(for type: DetectedEntity.EntityType) -> String {
        switch type {
        case .phoneNumber:    return "Phone Numbers"
        case .address:        return "Addresses"
        case .email:          return "Emails"
        case .url:            return "Links"
        case .otp:            return "OTP Codes"
        case .date:           return "Dates & Events"
        case .upiId:          return "UPI IDs"
        case .trackingNumber: return "Tracking Numbers"
        case .wifi:           return "Wifi Credentials"
        case .flightNumber:   return "Flight Numbers"
        case .currency:       return "Amounts"
        case .socialHandle:   return "Social Handles"
        case .ifscCode:       return "IFSC Codes"
        case .panNumber:      return "PAN Numbers"
        case .aadhaarNumber:  return "Aadhaar Numbers"
        case .gstNumber:      return "GST Numbers"
        case .coordinates:    return "Coordinates"
        case .orderId:        return "Order IDs"
        case .ipAddress:      return "IP Addresses"
        case .bankAccount:    return "Bank Accounts"
        }
    }
}
