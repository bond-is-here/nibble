import SwiftUI
#if os(iOS)
import UIKit
#endif

extension Color {
    static let ink = Color(hex: "242820")
    static let muted = Color(hex: "5E6257")
    static let canvas = Color(hex: "F7F7F2")
    static let lime = Color(hex: "D9F878")
    static let limeDark = Color(hex: "54692E")
    static let lilac = Color(hex: "E3DAF9")
    static let peach = Color(hex: "FADCC8")
    static let line = Color(hex: "E8E9E0")
    static let paper = Color.white
    static let fog = Color(hex: "EEEFE7")
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0
        self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}

extension View {
    /// Preserve Nibble's typography while following the person's Dynamic Type setting.
    func nibbleFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(NibbleFont(size: size, weight: weight, design: design))
    }
    func cardSurface(_ color: Color = .paper, padding: CGFloat = 20) -> some View {
        self.padding(padding).background(color, in: RoundedRectangle(cornerRadius: 26))
    }
    @ViewBuilder func numericKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
    @ViewBuilder func sentenceInput() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.sentences)
        #else
        self
        #endif
    }
    @ViewBuilder func phoneSheet() -> some View {
        #if os(macOS)
        self.frame(width: 420, height: 760)
        #else
        self.presentationDetents([.large]).presentationDragIndicator(.visible).presentationCornerRadius(32)
        #endif
    }
}

private struct NibbleFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        let style: Font.TextStyle = size >= 30 ? .largeTitle : size >= 20 ? .title3 : size >= 16 ? .body : .caption
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

/// Wide rows become a reading-order column at accessibility text sizes.
struct NibbleAdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var spacing: CGFloat = 12
    @ViewBuilder let content: () -> Content

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
        layout(content)
    }
}

enum NibbleHaptics {
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

struct NibbleButton: View {
    let title: String
    var icon: String = "arrow.right"
    var dark = true
    var action: () -> Void
    var body: some View {
        Button {
            NibbleHaptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                Text(title)
                Spacer(minLength: 8)
                Image(systemName: icon)
            }
            .nibbleFont(size: 16, weight: .semibold)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 23).padding(.vertical, 16).frame(minHeight: 56)
            .foregroundStyle(dark ? Color.white : Color.ink)
            .background(dark ? Color.ink : Color.lime, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct RoundButton: View {
    let icon: String
    let label: String
    var fill: Color = .fog
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .medium))
                .frame(width: 44, height: 44).foregroundStyle(Color.ink).background(fill, in: Circle())
                .contentShape(Circle())
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = .muted
    var body: some View {
        Text(text.uppercased()).nibbleFont(size: 10, weight: .bold, design: .monospaced)
            .tracking(1.8).foregroundStyle(color)
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        NibbleAdaptiveStack(spacing: 8) {
            Text(title).nibbleFont(size: 21, weight: .semibold, design: .rounded).tracking(-0.6)
                .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
            if let detail { Text(detail).nibbleFont(size: 11).foregroundStyle(Color.muted) }
        }.foregroundStyle(Color.ink)
    }
}

struct BiteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y) }
        p.move(to: point(0.76, 0.08))
        p.addCurve(to: point(0.1, 0.3), control1: point(0.4, -0.1), control2: point(0.05, 0.02))
        p.addCurve(to: point(0.13, 0.81), control1: point(-0.04, 0.49), control2: point(0.02, 0.7))
        p.addCurve(to: point(0.81, 0.91), control1: point(0.33, 1.07), control2: point(0.61, 1.0))
        p.addCurve(to: point(0.97, 0.48), control1: point(0.96, 0.79), control2: point(1.02, 0.63))
        p.addCurve(to: point(0.80, 0.39), control1: point(0.86, 0.52), control2: point(0.78, 0.48))
        p.addCurve(to: point(0.67, 0.24), control1: point(0.71, 0.42), control2: point(0.61, 0.33))
        p.addCurve(to: point(0.76, 0.08), control1: point(0.65, 0.14), control2: point(0.70, 0.1))
        p.closeSubpath()
        return p
    }
}

struct NibbleMascot: View {
    var color: Color = .lime
    var cheerful = false
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack {
                BiteShape().fill(color)
                Ellipse().fill(Color.ink).frame(width: w * 0.045, height: w * 0.10).position(x: w * 0.32, y: w * 0.46)
                Ellipse().fill(Color.ink).frame(width: w * 0.045, height: w * 0.10).position(x: w * 0.49, y: w * 0.46)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.33, y: w * 0.61))
                    p.addQuadCurve(to: CGPoint(x: w * 0.51, y: w * 0.61), control: CGPoint(x: w * 0.42, y: w * (cheerful ? 0.79 : 0.69)))
                }.stroke(Color.ink, style: StrokeStyle(lineWidth: w * 0.026, lineCap: .round))
                Circle().fill(Color.white.opacity(0.45)).frame(width: w * 0.08).position(x: w * 0.23, y: w * 0.57)
                Circle().fill(Color.white.opacity(0.45)).frame(width: w * 0.08).position(x: w * 0.58, y: w * 0.57)
            }
        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
    }
}

struct MacroTile: View {
    let name: String
    let value: Double
    let target: Double?
    let color: Color
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
                Text(name).font(.system(size: 11, weight: .medium))
            }
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value.whole).font(.system(size: 21, weight: .bold, design: .rounded)).contentTransition(.numericText())
                Text("g").font(.system(size: 11))
            }.lineLimit(1).minimumScaleFactor(0.8)
            if let target {
                GeometryReader { g in
                    Capsule().fill(Color.ink.opacity(0.09))
                    Capsule().fill(Color.ink.opacity(0.65)).frame(width: g.size.width * min(value / max(target, 1), 1))
                }.frame(height: 3)
                Text("of \(target.whole) g").font(.system(size: 9)).foregroundStyle(Color.ink)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(color, in: RoundedRectangle(cornerRadius: 21))
            .foregroundStyle(Color.ink).accessibilityElement(children: .combine)
    }
}

struct LabeledInput: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var unit = ""
    var numeric = true
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).nibbleFont(size: 12, weight: .medium).foregroundStyle(Color.muted)
            HStack {
                Group {
                    if numeric { TextField(placeholder, text: $text).numericKeyboard() }
                    else { TextField(placeholder, text: $text).sentenceInput() }
                }
                .textFieldStyle(.plain).nibbleFont(size: 20, weight: .semibold, design: .rounded)
                .accessibilityLabel(label)
                .accessibilityHint(unit.isEmpty ? "" : "Measured in \(unit)")
                if !unit.isEmpty { Text(unit).nibbleFont(size: 12).foregroundStyle(Color.muted) }
            }
            .padding(15).background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line))
        }.foregroundStyle(Color.ink)
    }
}

struct FoodBadge: View {
    let food: FoodItem
    var size: CGFloat = 48
    var body: some View {
        Text(food.emoji).font(.system(size: size * 0.52))
            .frame(width: size, height: size)
            .background(Color.fog, in: RoundedRectangle(cornerRadius: size * 0.3))
            .accessibilityHidden(true)
    }
}

struct MealSelector: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var selected: Meal
    var body: some View {
        NibbleAdaptiveStack(spacing: 5) {
            ForEach(Meal.allCases) { meal in
                Button { selected = meal } label: {
                    Text(meal.title).nibbleFont(size: 12, weight: .semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(selected == meal ? Color.ink : Color.clear, in: Capsule())
                        .foregroundStyle(selected == meal ? Color.white : Color.muted)
                        .contentShape(Capsule())
                }.buttonStyle(.plain).accessibilityAddTraits(selected == meal ? .isSelected : [])
            }
        }.padding(4).background(Color.fog, in: RoundedRectangle(cornerRadius: typeSize.isAccessibilitySize ? 24 : 50))
    }
}

struct InlineMessage: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "info.circle")
            .nibbleFont(size: 12).foregroundStyle(Color.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.peach, in: RoundedRectangle(cornerRadius: 16))
    }
}
