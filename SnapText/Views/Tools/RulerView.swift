import SwiftUI

struct RulerView: View {
    @State private var unit: RulerUnit = .cm

    // Screen PPI (points per inch) — iOS uses 163 PPI for standard, 326 for retina
    // UIScreen.main.scale gives us the scale factor
    private var pointsPerInch: CGFloat { 163.0 } // Logical points per inch on iOS

    private var pointsPerCm: CGFloat { pointsPerInch / 2.54 }

    enum RulerUnit: String, CaseIterable {
        case cm = "cm"
        case inch = "inch"
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Unit", selection: $unit) {
                ForEach(RulerUnit.allCases, id: \.self) { u in
                    Text(u.rawValue).tag(u)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Text("Place object against screen edge to measure")
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                let height = geo.size.height
                let width = geo.size.width

                ZStack(alignment: .topLeading) {
                    // Background
                    Color(.systemBackground)

                    // Vertical ruler (left side)
                    Canvas { context, size in
                        let tickSpacing: CGFloat = unit == .cm ? pointsPerCm : pointsPerInch
                        let subTicks = unit == .cm ? 10 : 8
                        let subSpacing = tickSpacing / CGFloat(subTicks)

                        var y: CGFloat = 0
                        var majorIndex = 0

                        while y < size.height {
                            // Major tick
                            let majorPath = Path { p in
                                p.move(to: CGPoint(x: 0, y: y))
                                p.addLine(to: CGPoint(x: 40, y: y))
                            }
                            context.stroke(majorPath, with: .color(.primary), lineWidth: 1.5)

                            // Label
                            let label = Text("\(majorIndex)")
                                .font(.caption2)
                                .foregroundColor(.primary)
                            context.draw(label, at: CGPoint(x: 50, y: y + 2), anchor: .leading)

                            // Sub-ticks
                            for sub in 1..<subTicks {
                                let subY = y + CGFloat(sub) * subSpacing
                                if subY >= size.height { break }
                                let isMid = (unit == .cm && sub == 5) || (unit == .inch && sub == 4)
                                let tickLen: CGFloat = isMid ? 28 : 16
                                let subPath = Path { p in
                                    p.move(to: CGPoint(x: 0, y: subY))
                                    p.addLine(to: CGPoint(x: tickLen, y: subY))
                                }
                                context.stroke(subPath, with: .color(.secondary), lineWidth: isMid ? 1.0 : 0.5)
                            }

                            majorIndex += 1
                            y += tickSpacing
                        }
                    }
                    .frame(width: 70, height: height)

                    // Horizontal ruler (top)
                    Canvas { context, size in
                        let tickSpacing: CGFloat = unit == .cm ? pointsPerCm : pointsPerInch
                        let subTicks = unit == .cm ? 10 : 8
                        let subSpacing = tickSpacing / CGFloat(subTicks)

                        var x: CGFloat = 70 // offset for vertical ruler
                        var majorIndex = 0

                        while x < size.width {
                            // Major tick
                            let majorPath = Path { p in
                                p.move(to: CGPoint(x: x, y: 0))
                                p.addLine(to: CGPoint(x: x, y: 40))
                            }
                            context.stroke(majorPath, with: .color(.primary), lineWidth: 1.5)

                            if majorIndex > 0 {
                                let label = Text("\(majorIndex)")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                                context.draw(label, at: CGPoint(x: x, y: 48), anchor: .top)
                            }

                            for sub in 1..<subTicks {
                                let subX = x + CGFloat(sub) * subSpacing
                                if subX >= size.width { break }
                                let isMid = (unit == .cm && sub == 5) || (unit == .inch && sub == 4)
                                let tickLen: CGFloat = isMid ? 28 : 16
                                let subPath = Path { p in
                                    p.move(to: CGPoint(x: subX, y: 0))
                                    p.addLine(to: CGPoint(x: subX, y: tickLen))
                                }
                                context.stroke(subPath, with: .color(.secondary), lineWidth: isMid ? 1.0 : 0.5)
                            }

                            majorIndex += 1
                            x += tickSpacing
                        }
                    }
                    .frame(width: width, height: 60)

                    // Corner label
                    Text(unit.rawValue)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 70, height: 60)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 1)
            )
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .navigationTitle("Ruler")
        .navigationBarTitleDisplayMode(.inline)
    }
}
