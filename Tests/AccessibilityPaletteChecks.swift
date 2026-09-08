import AppKit
import SwiftUI

/// Checks the actual shared palette, not duplicated hex constants.
@main
@MainActor
struct AccessibilityPaletteChecks {
    struct Failure: Error { let message: String }

    static func luminance(_ color: Color) throws -> Double {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else {
            throw Failure(message: "Palette color must resolve in sRGB")
        }
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
    }

    static func main() throws {
        let surfaces: [(String, Color)] = [("canvas", .canvas), ("paper", .paper), ("fog", .fog),
                                           ("lime", .lime), ("lilac", .lilac), ("peach", .peach)]
        var checks = 0
        for (foregroundName, foreground) in [("ink", Color.ink), ("muted", Color.muted)] {
            for (backgroundName, background) in surfaces {
                let first = try luminance(foreground), second = try luminance(background)
                let contrast = (max(first, second) + 0.05) / (min(first, second) + 0.05)
                checks += 1
                guard contrast >= 4.5 else {
                    throw Failure(message: "\(foregroundName) on \(backgroundName): \(contrast), expected at least 4.5:1")
                }
            }
        }
        print("Passed \(checks) shared text-palette contrast checks. Device audits still verify rendered controls and opacity.")
    }
}
