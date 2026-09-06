import Foundation

enum NutritionEngine {
    // Mifflin–St Jeor (1990). The midpoint is explicitly labeled in setup.
    static func basalMetabolicRate(for profile: UserProfile) -> Double {
        let base = 10 * profile.weightKilograms + 6.25 * profile.heightCentimeters - 5 * Double(profile.age)
        return base + (profile.sex == .male ? 5 : profile.sex == .female ? -161 : -78)
    }

    static func targets(for profile: UserProfile) -> MacroTargets {
        let maintenance = basalMetabolicRate(for: profile) * profile.activity.multiplier
        let adjustment = profile.goal == .lose ? -min(300, maintenance * 0.15) : profile.goal.calorieAdjustment
        // Product guardrail for automated estimates, not a clinical minimum.
        let calories = max(1_500, ((maintenance + adjustment) / 50).rounded() * 50)
        return balancedTargets(calories: calories)
    }

    static func balancedTargets(calories: Double) -> MacroTargets {
        // A transparent starting split. Macro calories sum to the calorie target.
        MacroTargets(calories: calories, protein: calories * 0.25 / 4, carbs: calories * 0.45 / 4, fat: calories * 0.30 / 9)
    }

    static func poundsToKilograms(_ pounds: Double) -> Double { pounds / 2.20462 }
    static func kilogramsToPounds(_ kilograms: Double) -> Double { kilograms * 2.20462 }
    static func inchesToCentimeters(_ inches: Double) -> Double { inches * 2.54 }
    static func centimetersToInches(_ centimeters: Double) -> Double { centimeters / 2.54 }
}
