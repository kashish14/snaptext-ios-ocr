import SwiftUI

struct UnitConverterView: View {
    @State private var selectedCategory = 0
    @State private var inputValue = ""
    @State private var fromIndex = 0
    @State private var toIndex = 1

    private let categories = UnitCategory.allCategories

    private var currentCategory: UnitCategory { categories[selectedCategory] }

    private var result: String {
        guard let value = Double(inputValue) else { return "" }
        let fromUnit = currentCategory.units[fromIndex]
        let toUnit = currentCategory.units[toIndex]
        let baseValue = value * fromUnit.toBase
        let converted = baseValue / toUnit.toBase
        if converted == floor(converted) && abs(converted) < 1e12 {
            return String(format: "%.0f", converted)
        }
        return String(format: "%.4f", converted)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Category picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories.indices, id: \.self) { index in
                            Button {
                                selectedCategory = index
                                fromIndex = 0
                                toIndex = min(1, categories[index].units.count - 1)
                                inputValue = ""
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: categories[index].icon)
                                        .font(.title3)
                                    Text(categories[index].name)
                                        .font(.caption2)
                                }
                                .frame(width: 70, height: 60)
                                .background(selectedCategory == index ? Color.accentColor : Color(.secondarySystemBackground))
                                .foregroundStyle(selectedCategory == index ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // From
                VStack(alignment: .leading, spacing: 8) {
                    Text("From")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("Value", text: $inputValue)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Picker("", selection: $fromIndex) {
                            ForEach(currentCategory.units.indices, id: \.self) { i in
                                Text(currentCategory.units[i].symbol).tag(i)
                            }
                        }
                        .frame(width: 100)
                    }
                }
                .padding(.horizontal)

                // Swap button
                Button {
                    let tmp = fromIndex
                    fromIndex = toIndex
                    toIndex = tmp
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.title)
                        .foregroundStyle(.tint)
                }

                // To
                VStack(alignment: .leading, spacing: 8) {
                    Text("To")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(result.isEmpty ? "0" : result)
                            .font(.title2.bold())
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onTapGesture {
                                if !result.isEmpty {
                                    ClipboardManager.shared.copy(result, source: "Converter")
                                }
                            }

                        Picker("", selection: $toIndex) {
                            ForEach(currentCategory.units.indices, id: \.self) { i in
                                Text(currentCategory.units[i].symbol).tag(i)
                            }
                        }
                        .frame(width: 100)
                    }
                }
                .padding(.horizontal)

                if !result.isEmpty {
                    Text("Tap result to copy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Unit Converter")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Unit Data

private struct ConvertibleUnit {
    let name: String
    let symbol: String
    let toBase: Double // multiply by this to convert to base unit
}

private struct UnitCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let units: [ConvertibleUnit]

    static let allCategories: [UnitCategory] = [
        UnitCategory(name: "Length", icon: "ruler", units: [
            ConvertibleUnit(name: "Millimeter", symbol: "mm", toBase: 0.001),
            ConvertibleUnit(name: "Centimeter", symbol: "cm", toBase: 0.01),
            ConvertibleUnit(name: "Meter", symbol: "m", toBase: 1),
            ConvertibleUnit(name: "Kilometer", symbol: "km", toBase: 1000),
            ConvertibleUnit(name: "Inch", symbol: "in", toBase: 0.0254),
            ConvertibleUnit(name: "Foot", symbol: "ft", toBase: 0.3048),
            ConvertibleUnit(name: "Yard", symbol: "yd", toBase: 0.9144),
            ConvertibleUnit(name: "Mile", symbol: "mi", toBase: 1609.34),
        ]),
        UnitCategory(name: "Weight", icon: "scalemass", units: [
            ConvertibleUnit(name: "Milligram", symbol: "mg", toBase: 0.001),
            ConvertibleUnit(name: "Gram", symbol: "g", toBase: 1),
            ConvertibleUnit(name: "Kilogram", symbol: "kg", toBase: 1000),
            ConvertibleUnit(name: "Pound", symbol: "lb", toBase: 453.592),
            ConvertibleUnit(name: "Ounce", symbol: "oz", toBase: 28.3495),
            ConvertibleUnit(name: "Tonne", symbol: "t", toBase: 1_000_000),
        ]),
        UnitCategory(name: "Temp", icon: "thermometer.medium", units: [
            ConvertibleUnit(name: "Celsius", symbol: "\u{00B0}C", toBase: 1),     // special handling
            ConvertibleUnit(name: "Fahrenheit", symbol: "\u{00B0}F", toBase: 1),
            ConvertibleUnit(name: "Kelvin", symbol: "K", toBase: 1),
        ]),
        UnitCategory(name: "Area", icon: "square.dashed", units: [
            ConvertibleUnit(name: "Sq Meter", symbol: "m\u{00B2}", toBase: 1),
            ConvertibleUnit(name: "Sq Km", symbol: "km\u{00B2}", toBase: 1_000_000),
            ConvertibleUnit(name: "Sq Foot", symbol: "ft\u{00B2}", toBase: 0.0929),
            ConvertibleUnit(name: "Acre", symbol: "ac", toBase: 4046.86),
            ConvertibleUnit(name: "Hectare", symbol: "ha", toBase: 10000),
        ]),
        UnitCategory(name: "Volume", icon: "drop", units: [
            ConvertibleUnit(name: "Milliliter", symbol: "mL", toBase: 0.001),
            ConvertibleUnit(name: "Liter", symbol: "L", toBase: 1),
            ConvertibleUnit(name: "Gallon (US)", symbol: "gal", toBase: 3.78541),
            ConvertibleUnit(name: "Cup", symbol: "cup", toBase: 0.236588),
            ConvertibleUnit(name: "Fluid Oz", symbol: "fl oz", toBase: 0.0295735),
        ]),
        UnitCategory(name: "Speed", icon: "speedometer", units: [
            ConvertibleUnit(name: "m/s", symbol: "m/s", toBase: 1),
            ConvertibleUnit(name: "km/h", symbol: "km/h", toBase: 0.277778),
            ConvertibleUnit(name: "mph", symbol: "mph", toBase: 0.44704),
            ConvertibleUnit(name: "Knot", symbol: "kn", toBase: 0.514444),
        ]),
        UnitCategory(name: "Data", icon: "internaldrive", units: [
            ConvertibleUnit(name: "Byte", symbol: "B", toBase: 1),
            ConvertibleUnit(name: "Kilobyte", symbol: "KB", toBase: 1024),
            ConvertibleUnit(name: "Megabyte", symbol: "MB", toBase: 1_048_576),
            ConvertibleUnit(name: "Gigabyte", symbol: "GB", toBase: 1_073_741_824),
            ConvertibleUnit(name: "Terabyte", symbol: "TB", toBase: 1_099_511_627_776),
        ]),
        UnitCategory(name: "Time", icon: "clock", units: [
            ConvertibleUnit(name: "Second", symbol: "sec", toBase: 1),
            ConvertibleUnit(name: "Minute", symbol: "min", toBase: 60),
            ConvertibleUnit(name: "Hour", symbol: "hr", toBase: 3600),
            ConvertibleUnit(name: "Day", symbol: "day", toBase: 86400),
            ConvertibleUnit(name: "Week", symbol: "wk", toBase: 604800),
        ]),
    ]
}
