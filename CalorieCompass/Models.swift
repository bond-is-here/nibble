import Foundation

enum Sex: String, CaseIterable, Codable, Identifiable {
    case female, male, unspecified
    var id: String { rawValue }
    var title: String { self == .unspecified ? "Use midpoint" : rawValue.capitalized }
}

enum ActivityLevel: String, CaseIterable, Codable, Identifiable {
    case sedentary, lightlyActive, moderatelyActive, veryActive
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sedentary: return "Mostly sitting"
        case .lightlyActive: return "Some movement"
        case .moderatelyActive: return "Regular exercise"
        case .veryActive: return "Very active"
        }
    }
    var subtitle: String {
        switch self {
        case .sedentary: return "A desk-based day"
        case .lightlyActive: return "Walks & light exercise"
        case .moderatelyActive: return "Exercise 3–5 days a week"
        case .veryActive: return "Physical work or daily training"
        }
    }
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        }
    }
}

enum Goal: String, CaseIterable, Codable, Identifiable {
    case lose, maintain, gain
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lose: return "Lose slowly"
        case .maintain: return "Find my balance"
        case .gain: return "Gain gradually"
        }
    }
    var icon: String { self == .lose ? "arrow.down.right" : self == .gain ? "arrow.up.right" : "equal" }
    var calorieAdjustment: Double { self == .lose ? -300 : self == .gain ? 250 : 0 }
}

enum Meal: String, CaseIterable, Codable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon"
        case .snack: return "sparkles"
        }
    }
    static func suggested(at date: Date = Date()) -> Meal {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<22: return .dinner
        default: return .snack
        }
    }
}

enum DisplayUnits: String, CaseIterable, Codable, Identifiable {
    case metric, imperial
    var id: String { rawValue }
    var title: String { self == .metric ? "kg / cm" : "lb / in" }
}

struct UserProfile: Codable, Equatable {
    var heightCentimeters: Double
    var weightKilograms: Double
    var age: Int
    var sex: Sex
    var activity: ActivityLevel
    var goal: Goal
    var goalWeightKilograms: Double
    var displayUnits: DisplayUnits? = nil
    var heightFeet: Int { Int((heightCentimeters / 2.54).rounded()) / 12 }
    var heightInchesRemainder: Int { Int((heightCentimeters / 2.54).rounded()) % 12 }
    var weightPounds: Double { weightKilograms * 2.20462 }
    var goalWeightPounds: Double { goalWeightKilograms * 2.20462 }
    var isValid: Bool {
        heightCentimeters.isFinite && (120...230).contains(heightCentimeters)
        && weightKilograms.isFinite && (35...300).contains(weightKilograms)
        && (18...100).contains(age) && goalWeightKilograms.isFinite
        && (35...300).contains(goalWeightKilograms)
    }
}

struct FoodItem: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var brand: String?
    var servingText: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var barcode: String?
    var source: FoodSource = .local
    // Optional so the first release's saved foods remain decodable.
    var macrosComplete: Bool? = nil
    var hasMacros: Bool { macrosComplete != false }
    var isPerHundred: Bool {
        let basis = servingText.lowercased().replacingOccurrences(of: "per", with: "").replacingOccurrences(of: " ", with: "")
        return basis == "100g" || basis == "100ml"
    }
    var quantityUnit: String { isPerHundred ? (servingText.lowercased().contains("ml") ? "ml" : "g") : "servings" }
    var stableKey: String { barcode.map { "barcode:\($0)" } ?? "\(name.lowercased())|\(servingText.lowercased())" }
    var shortNutrition: String { "\(calories.whole) cal · \(protein.whole)g protein" }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !servingText.isEmpty
        && [calories, protein, carbs, fat].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 10_000 }
    }
    var emoji: String {
        let text = name.lowercased()
        let pairs = [("yogurt", "🥣"), ("banana", "🍌"), ("egg", "🍳"), ("chicken", "🍗"), ("oat", "🥣"), ("avocado", "🥑"), ("salmon", "🍣"), ("toast", "🍞"), ("smoothie", "🫐"), ("apple", "🍎"), ("rice", "🍚"), ("coffee", "☕️"), ("almond", "🥜"), ("milk", "🥛"), ("pasta", "🍝"), ("potato", "🥔"), ("salad", "🥗"), ("chocolate", "🍫")]
        return pairs.first { text.contains($0.0) }?.1 ?? "🍽️"
    }
}

enum FoodSource: String, Codable { case local, openFoodFacts, custom }

struct FoodLogEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var meal: Meal
    var food: FoodItem
    var servings: Double
    var calories: Double { food.calories * servings }
    var protein: Double { food.protein * servings }
    var carbs: Double { food.carbs * servings }
    var fat: Double { food.fat * servings }
    var portionDescription: String {
        food.isPerHundred ? "\((servings * 100).compact) \(food.quantityUnit)" : "\(servings.compact) × \(food.servingText)"
    }
}

struct DailyTotals {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var hasIncompleteMacros = false
    init(entries: [FoodLogEntry] = []) {
        for entry in entries {
            calories += entry.calories
            protein += entry.protein
            carbs += entry.carbs
            fat += entry.fat
            hasIncompleteMacros = hasIncompleteMacros || !entry.food.hasMacros
        }
    }
}

struct MacroTargets: Codable, Equatable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
}

struct DiaryArchive: Codable, Equatable {
    var version = 1
    var hasStarted = false
    var profile: UserProfile?
    var calorieTarget: Double?
    var entries: [FoodLogEntry] = []
    var savedFoods: [FoodItem] = []
    var favorites: Set<String> = []
    var units: DisplayUnits = .imperial
}

extension Double {
    var whole: String { formatted(.number.precision(.fractionLength(0))) }
    var compact: String { formatted(.number.precision(.fractionLength(0...1))) }
    // Editable quantities must round-trip without localized thousands separators.
    var inputString: String {
        let raw = String(self)
        return raw.hasSuffix(".0") ? String(raw.dropLast(2)) : raw
    }
    var shortInput: String { ((self * 10).rounded() / 10).inputString }
}

extension Date {
    var shortDay: String { formatted(.dateTime.weekday(.abbreviated)) }
    var diaryTitle: String {
        Calendar.current.isDateInToday(self) ? "Today" : Calendar.current.isDateInYesterday(self) ? "Yesterday" : formatted(.dateTime.month(.abbreviated).day())
    }
}
