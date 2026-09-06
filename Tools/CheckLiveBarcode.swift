import Foundation

@main
struct CheckLiveBarcode {
    static func main() async throws {
        let code = CommandLine.arguments.dropFirst().first ?? "3017620422003"
        let food = try await OpenFoodFactsClient().lookup(barcode: code)
        print("\(food.name) — \(food.servingText), \(food.calories.whole) cal, P \(food.protein.compact) / C \(food.carbs.compact) / F \(food.fat.compact)")
    }
}
