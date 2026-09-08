import Foundation

enum MacroKind: String, CaseIterable, Identifiable {
    case protein, carbs, fat
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var letter: String { String(title.prefix(1)) }
    var caloriesPerGram: Double { self == .fat ? 9 : 4 }
    func grams(in totals: DailyTotals) -> Double {
        switch self {
        case .protein: return totals.protein
        case .carbs: return totals.carbs
        case .fat: return totals.fat
        }
    }
    func grams(in targets: MacroTargets) -> Double {
        switch self {
        case .protein: return targets.protein
        case .carbs: return targets.carbs
        case .fat: return targets.fat
        }
    }
    func grams(in food: FoodItem) -> Double {
        guard food.hasMacros else { return 0 }
        switch self {
        case .protein: return food.protein
        case .carbs: return food.carbs
        case .fat: return food.fat
        }
    }
}

struct MacroSnapshot {
    let entries: [FoodLogEntry]
    let targets: MacroTargets?
    var totals: DailyTotals { DailyTotals(entries: entries) }
    var knownCount: Int { entries.filter { $0.food.hasMacros }.count }
    var missingCount: Int { entries.count - knownCount }
    var isPartial: Bool { missingCount > 0 }
    var knownEnergy: Double { MacroKind.allCases.reduce(0) { $0 + $1.grams(in: totals) * $1.caloriesPerGram } }
    var coverageText: String {
        if entries.isEmpty { return "No bites logged yet" }
        return "\(knownCount) of \(entries.count) bites include macros"
    }
    func share(_ macro: MacroKind) -> Double {
        guard knownEnergy > 0 else { return 0 }
        return macro.grams(in: totals) * macro.caloriesPerGram / knownEnergy
    }
    func progress(_ macro: MacroKind) -> Double? {
        guard let targets, macro.grams(in: targets) > 0 else { return nil }
        return macro.grams(in: totals) / macro.grams(in: targets)
    }
    func contributors(to macro: MacroKind) -> [FoodLogEntry] {
        entries.filter { $0.food.hasMacros && macro.grams(in: $0.food) > 0 }
            .sorted {
                let a = macro.grams(in: $0.food) * $0.servings
                let b = macro.grams(in: $1.food) * $1.servings
                return a == b ? $0.id.uuidString < $1.id.uuidString : a > b
            }
    }
}

enum MacroNudge: Equatable {
    case empty, incomplete, observing, history, enoughForNow, noMatch
    case explore(MacroKind)
    var title: String {
        switch self {
        case .empty: return "Your mix starts with a bite."
        case .incomplete: return "A few pieces are missing."
        case .observing: return "A mix, not a score."
        case .history: return "A snapshot, not homework."
        case .enoughForNow: return "No need to chase perfect rings."
        case .noMatch: return "Your next bite is up to you."
        case .explore(let macro): return "A little room for \(macro.title.lowercased())."
        }
    }
    var detail: String {
        switch self {
        case .empty: return "Log a food with its label to start seeing your protein, carbs, and fat."
        case .incomplete: return "Some foods have calories only. We show known grams and pause target-based suggestions instead of guessing."
        case .observing: return "You’re tracking without targets. The colors describe your logged macro energy; there’s no ideal shape to chase."
        case .history: return "This is the day you selected. Any target comparison uses your current plan, not a saved historical goal."
        case .enoughForNow: return "Logged totals have reached your calorie target or all three macro targets. This isn’t a signal to stop eating or compensate."
        case .noMatch: return "No serving with complete macro data in your library fits this comparison. Choose what works for you."
        case .explore: return "This macro has the most room relative to your current targets. If you’re looking for an idea, explore a familiar food below."
        }
    }
}

struct MacroSuggestion: Identifiable {
    let food: FoodItem
    let focus: MacroKind
    let score: Double
    var id: String { food.stableKey }
}

struct MacroInsight {
    let nudge: MacroNudge
    let suggestions: [MacroSuggestion]
}

enum MacroEngine {
    static func preview(snapshot: MacroSnapshot, food: FoodItem, servings: Double, replacing id: UUID? = nil) -> MacroSnapshot? {
        guard food.isValid, servings.isFinite, (0.01...100).contains(servings) else { return nil }
        if let id, !snapshot.entries.contains(where: { $0.id == id }) { return nil }
        var entries = snapshot.entries.filter { $0.id != id }
        entries.append(FoodLogEntry(meal: .snack, food: food, servings: servings))
        return MacroSnapshot(entries: entries, targets: snapshot.targets)
    }

    // A transparent local ranking, not an AI nutritionist or a clinical recommendation.
    // Never infer missing macros, offer catch-up advice for the past, or auto-log food.
    static func insight(snapshot: MacroSnapshot, foods: [FoodItem], favorites: Set<String> = [], isToday: Bool) -> MacroInsight {
        func message(_ nudge: MacroNudge) -> MacroInsight { MacroInsight(nudge: nudge, suggestions: []) }
        guard !snapshot.entries.isEmpty else { return message(.empty) }
        guard !snapshot.isPartial else { return message(.incomplete) }
        guard isToday else { return message(.history) }
        guard let targets = snapshot.targets,
              [targets.calories, targets.protein, targets.carbs, targets.fat].allSatisfy({ $0.isFinite && $0 > 0 })
        else { return message(.observing) }
        let totals = snapshot.totals
        let remainingCalories = targets.calories - totals.calories
        let ordered = MacroKind.allCases.sorted {
            let a = $0.grams(in: totals) / $0.grams(in: targets)
            let b = $1.grams(in: totals) / $1.grams(in: targets)
            return a == b ? $0.rawValue < $1.rawValue : a < b
        }
        guard remainingCalories > 0, let focus = ordered.first,
              focus.grams(in: totals) < focus.grams(in: targets) else { return message(.enoughForNow) }
        var seen = Set<String>()
        let ranked = foods.compactMap { food -> MacroSuggestion? in
            guard food.isValid, food.hasMacros, food.calories > 0, food.calories <= remainingCalories,
                  focus.grams(in: food) > 0, seen.insert(food.stableKey).inserted else { return nil }
            let filled = min(focus.grams(in: food), focus.grams(in: targets) - focus.grams(in: totals)) / focus.grams(in: targets)
            let overshoot = MacroKind.allCases.reduce(0.0) { result, macro in
                let room = max(0, macro.grams(in: targets) - macro.grams(in: totals))
                return result + max(0, macro.grams(in: food) - room) / macro.grams(in: targets)
            }
            let score = filled - overshoot * 0.5
            guard score > 0 else { return nil }
            return MacroSuggestion(food: food, focus: focus, score: score)
        }.sorted {
            // Exact score ordering stays transitive, including very close scores.
            if $0.score != $1.score { return $0.score > $1.score }
            let a = favorites.contains($0.id), b = favorites.contains($1.id)
            return a == b ? $0.id < $1.id : a
        }
        return ranked.isEmpty ? message(.noMatch) : MacroInsight(nudge: .explore(focus), suggestions: Array(ranked.prefix(3)))
    }
}

struct MacroWeek {
    let days: [Date]
    let snapshots: [MacroSnapshot]
    init(entries: [FoodLogEntry], ending date: Date, calendar: Calendar = .current) {
        let end = calendar.startOfDay(for: date)
        days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: end) }
        snapshots = days.map { day in MacroSnapshot(entries: entries.filter { calendar.isDate($0.date, inSameDayAs: day) }, targets: nil) }
    }
    var daysWithMacros: Int { snapshots.filter { $0.knownCount > 0 }.count }
    var missingCount: Int { snapshots.reduce(0) { $0 + $1.missingCount } }
    func average(_ macro: MacroKind) -> Double? {
        guard daysWithMacros > 0 else { return nil }
        return snapshots.reduce(0) { $0 + macro.grams(in: $1.totals) } / Double(daysWithMacros)
    }
}
