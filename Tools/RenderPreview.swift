import SwiftUI
import AppKit

// Renders the actual shared SwiftUI views. This is not an iOS Simulator screenshot.
@main
struct RenderPreview {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Design")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let demo = AppState(demo: true)
        try render(PhoneFrame { MainTabView().environmentObject(demo) }, name: "nibble-diary", output: output)
        try render(PhoneFrame { AddFoodView(initialMeal: .lunch).environmentObject(demo) }, name: "nibble-add-food", output: output)
        try render(PhoneFrame { OnboardingView().environmentObject(demo) }, name: "nibble-welcome", output: output)
        try render(PhoneFrame { FoodPortionView(food: AppState.foodDatabase[3], initialMeal: .lunch).environmentObject(demo) }, name: "nibble-portion", output: output)
        try render(PhoneFrame { LogView().environmentObject(demo) }, name: "nibble-patterns", output: output)
        try render(
            ZStack {
                Color.ink
                NibbleMascot(color: .lime, cheerful: true).frame(width: 720, height: 720).rotationEffect(.degrees(-10))
            }.frame(width: 1024, height: 1024),
            name: "AppIcon", output: output, scale: 1
        )
        try render(DesignBoard(output: output), name: "nibble-overview", output: output, size: NSSize(width: 1500, height: 1160))
    }

    @MainActor static func render<V: View>(_ content: V, name: String, output: URL, scale: CGFloat = 2, size: NSSize = NSSize(width: 430, height: 932)) throws {
        if name == "AppIcon" {
            let renderer = ImageRenderer(content: content)
            renderer.scale = 1
            guard let image = renderer.cgImage,
                  let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw CocoaError(.fileWriteUnknown) }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
            guard let opaque = context.makeImage(),
                  let data = NSBitmapImageRep(cgImage: opaque).representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: output.appendingPathComponent(name + ".png"), options: .atomic)
            print("Rendered opaque 1024 px AppIcon.png")
            return
        }
        // NSHostingView renders native scrolling/input controls that ImageRenderer omits.
        let hosting = NSHostingView(rootView: content.environment(\.colorScheme, .light))
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { throw CocoaError(.fileWriteUnknown) }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: output.appendingPathComponent(name + ".png"), options: .atomic)
        print("Rendered \(name).png")
    }
}

private struct DesignBoard: View {
    let output: URL
    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("nibble.").font(.system(size: 67, weight: .black, design: .rounded)).tracking(-4)
                    Text("Little bites. Real life.").font(.system(size: 22))
                }
                Spacer()
                Text("LESS LOGGING. MORE LIVING.").font(.system(size: 12, weight: .medium, design: .monospaced)).tracking(2)
                    .padding(.bottom, 8)
            }
            HStack(alignment: .top, spacing: 34) {
                panel("nibble-welcome", label: "01   MAKE IT YOURS")
                panel("nibble-diary", label: "02   YOUR DAILY BITE")
                panel("nibble-add-food", label: "03   ONE TAP & ON WITH YOUR DAY")
            }
            HStack {
                Text("Native SwiftUI · iOS 17+").font(.system(size: 12, weight: .medium))
                Spacer()
                Text("Design preview rendered from the app · sample diary data").font(.system(size: 11))
            }.foregroundStyle(Color.muted)
        }.padding(55).frame(width: 1500, height: 1160).background(Color(hex: "EDEEE6")).foregroundStyle(Color.ink)
    }
    private func panel(_ file: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if let image = NSImage(contentsOf: output.appendingPathComponent(file + ".png")) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 430, height: 932).clipShape(RoundedRectangle(cornerRadius: 39))
                    .overlay(RoundedRectangle(cornerRadius: 39).stroke(Color.ink.opacity(0.07), lineWidth: 1))
                    .scaleEffect(0.87, anchor: .topLeading).frame(width: 374, height: 811, alignment: .topLeading)
            }
            Text(label).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5)
        }.frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct PhoneFrame<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("9:41").font(.system(size: 14, weight: .semibold))
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "cellularbars")
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100percent")
                }.font(.system(size: 12, weight: .semibold))
            }.padding(.horizontal, 31).frame(height: 47).foregroundStyle(Color.ink)
            content().frame(maxWidth: .infinity, maxHeight: .infinity)
            Capsule().fill(Color.ink).frame(width: 130, height: 5).padding(.vertical, 9)
        }.frame(width: 430, height: 932).background(Color.canvas)
    }
}
