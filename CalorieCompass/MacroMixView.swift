import SwiftUI

extension MacroKind {
    var color: Color { self == .protein ? .peach : self == .carbs ? .lilac : .lime }
    var symbol: String { self == .protein ? "bolt.fill" : self == .carbs ? "sparkle" : "drop.fill" }
}

struct MacroOrbit: View {
    let snapshot: MacroSnapshot
    var focus: MacroKind? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            ForEach(Array(MacroKind.allCases.enumerated()), id: \.element.id) { index, macro in
                let fraction = min(max(snapshot.progress(macro) ?? snapshot.share(macro), 0), 1)
                Circle().stroke(Color.ink.opacity(0.055), lineWidth: 11).padding(CGFloat(index) * 17)
                Circle().trim(from: 0, to: fraction)
                    .stroke(macro.color, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90)).padding(CGFloat(index) * 17)
            }
            VStack(spacing: 4) {
                if let focus {
                    Text(snapshot.knownCount == 0 ? "—" : focus.grams(in: snapshot.totals).compact)
                        .font(.system(size: 24, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                    Text("g \(focus.title.lowercased())").font(.system(size: 9, weight: .medium))
                } else {
                    Image(systemName: "sparkle").font(.system(size: 22))
                    Text("YOUR MIX").font(.system(size: 7, weight: .bold, design: .monospaced)).tracking(1)
                }
            }.padding(45)
        }.foregroundStyle(Color.ink).aspectRatio(1, contentMode: .fit)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: MacroKind.allCases.map { $0.grams(in: snapshot.totals) })
            .accessibilityHidden(true)
    }
}

struct MacroMixCard: View {
    let snapshot: MacroSnapshot
    let onOpen: (MacroKind) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                SectionHeading(title: "Macro Mix")
                Button { onOpen(.protein) } label: {
                    HStack(spacing: 5) { Text("Explore"); Image(systemName: "arrow.up.right") }
                        .nibbleFont(size: 12, weight: .semibold).frame(minHeight: 44)
                }.buttonStyle(.plain).accessibilityLabel("Explore your macro mix")
            }
            NibbleAdaptiveStack(spacing: 23) {
                MacroOrbit(snapshot: snapshot).frame(width: 132)
                VStack(spacing: 12) {
                    ForEach(MacroKind.allCases) { macro in
                        Button { onOpen(macro) } label: {
                            HStack(spacing: 8) {
                                Circle().fill(macro.color).frame(width: 9, height: 9)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(macro.title).nibbleFont(size: 12, weight: .medium)
                                    Text(valueText(macro)).nibbleFont(size: 12, weight: .semibold, design: .rounded)
                                }
                                Spacer(minLength: 0)
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("\(macro.title), \(valueText(macro)). Explore details")
                    }
                }.frame(maxWidth: .infinity)
            }
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: snapshot.isPartial ? "circle.lefthalf.filled" : "circle.grid.2x2")
                Text(snapshot.isPartial ? "Known grams only · \(snapshot.missingCount) calorie-only \(snapshot.missingCount == 1 ? "bite" : "bites")" : snapshot.targets == nil ? "Share of logged macro energy. No target needed." : "Progress toward your current plan. Not a score.")
            }.nibbleFont(size: 10).foregroundStyle(Color.muted)
        }.foregroundStyle(Color.ink).cardSurface()
    }
    private func valueText(_ macro: MacroKind) -> String {
        guard snapshot.knownCount > 0 else { return snapshot.entries.isEmpty ? "0 g logged" : "— unknown" }
        let value = "\(macro.grams(in: snapshot.totals).compact) g"
        return snapshot.targets.map { value + " / \(macro.grams(in: $0).whole) g" } ?? value
    }
}

struct MacroMixView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var focus: MacroKind
    @State private var showMixingDesk = false
    @State private var selectedFood: FoodItem?
    init(initialFocus: MacroKind = .protein) { _focus = State(initialValue: initialFocus) }
    private var snapshot: MacroSnapshot { MacroSnapshot(entries: appState.selectedEntries, targets: appState.targets) }
    private var insight: MacroInsight {
        MacroEngine.insight(snapshot: snapshot, foods: appState.allFoods, favorites: appState.archive.favorites,
                            isToday: Calendar.current.isDateInToday(appState.selectedDate))
    }
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Eyebrow(text: appState.selectedDate.diaryTitle + " · the full picture")
                        Text("Macro Mix.").nibbleFont(size: 34, weight: .bold, design: .rounded).tracking(-1.4)
                    }
                    Spacer()
                    RoundButton(icon: "xmark", label: "Close macro mix") { dismiss() }
                }
                mixPanel
                nudgePanel
                mealPanel
                contributorPanel
                DisclosureGroup("How this little brain works") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("All insights run on your device. Nibble compares known grams with your current targets, then ranks servings with all three macros from the starter library and your saved foods. It favors filling the largest proportional gap while limiting overshoot; favorites break ties. Starter foods are estimates. Suggestions don’t account for allergies or dietary restrictions.")
                        Text("Suggestions pause for calorie-only entries, past dates, no targets, or totals already at the calorie/all-macro targets. A partial diary is not your full day. These are food-library ideas, not medical advice or instructions to eat less or more.")
                        Text("The mix uses 4 calories per gram of protein/carbs and 9 per gram of fat. It describes known macro energy, not a plate’s weight or your total label calories; fiber, alcohol, rounding, and other factors can make those differ.")
                        Link("FDA: Understanding nutrition labels ↗", destination: URL(string: "https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label")!)
                        Text("Current split: \(appState.macroSplit.protein)% protein / \(appState.macroSplit.carbs)% carbs / \(appState.macroSplit.fat)% fat. The default 25/45/30 is a starting point, not a personal prescription. Historical views compare against your current plan.")
                    }.nibbleFont(size: 12).foregroundStyle(Color.muted).padding(.top, 12)
                }.nibbleFont(size: 13, weight: .semibold).cardSurface()
            }.padding(24).foregroundStyle(Color.ink)
        }.background(Color.canvas)
            .sheet(isPresented: $showMixingDesk) { MacroSplitEditor().phoneSheet() }
            .sheet(item: $selectedFood) { food in FoodPortionView(food: food, initialMeal: .suggested()).phoneSheet() }
    }

    private var mixPanel: some View {
        VStack(spacing: 20) {
            MacroOrbit(snapshot: snapshot, focus: focus).frame(width: 184, height: 184).padding(.top, 8)
            NibbleAdaptiveStack(spacing: 7) {
                ForEach(MacroKind.allCases) { macro in
                    Button { focus = macro; NibbleHaptics.tap() } label: {
                        VStack(spacing: 6) {
                            Label(macro.title, systemImage: macro.symbol).nibbleFont(size: 11, weight: .semibold)
                            Text(snapshot.knownCount == 0 && !snapshot.entries.isEmpty ? "—" : "\(macro.grams(in: snapshot.totals).compact) g")
                                .nibbleFont(size: 17, weight: .bold, design: .rounded)
                        }.frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(focus == macro ? macro.color : Color.fog, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(focus == macro ? Color.ink.opacity(0.5) : .clear))
                    }.buttonStyle(.plain).accessibilityAddTraits(focus == macro ? .isSelected : [])
                }
            }
            VStack(spacing: 6) {
                if snapshot.isPartial { Text("PARTIAL · KNOWN GRAMS ONLY").nibbleFont(size: 9, weight: .bold, design: .monospaced) }
                if let targets = snapshot.targets {
                    let amount = focus.grams(in: snapshot.totals), target = focus.grams(in: targets)
                    Text(snapshot.knownCount == 0 && !snapshot.entries.isEmpty ? "\(target.whole) g current target · amount unknown" : "\(abs(target - amount).compact) g \(amount <= target ? "to current target" : "above current target")")
                        .nibbleFont(size: 14, weight: .semibold)
                    Text("\(target.compact) g target · \(snapshot.coverageText)").nibbleFont(size: 11).foregroundStyle(Color.muted)
                } else {
                    Text(snapshot.knownEnergy > 0 ? "\((snapshot.share(focus) * 100).whole)% of known macro energy" : "Your mix appears as you log")
                        .nibbleFont(size: 14, weight: .semibold)
                    Text(snapshot.coverageText).nibbleFont(size: 11).foregroundStyle(Color.muted)
                }
            }.multilineTextAlignment(.center)
            Button { showMixingDesk = true } label: {
                Label("Open the mixing desk", systemImage: "slider.horizontal.3").nibbleFont(size: 13, weight: .semibold)
                    .frame(maxWidth: .infinity, minHeight: 44).background(Color.fog, in: Capsule())
            }.buttonStyle(.plain)
        }.cardSurface()
    }

    private var nudgePanel: some View {
        VStack(alignment: .leading, spacing: 15) {
            Eyebrow(text: "Next little bite", color: .ink)
            Text(insight.nudge.title).nibbleFont(size: 23, weight: .semibold, design: .rounded).tracking(-0.5)
            Text(insight.nudge.detail).nibbleFont(size: 13).foregroundStyle(Color.ink).lineSpacing(3)
            ForEach(insight.suggestions) { suggestion in
                Button { selectedFood = suggestion.food } label: {
                    HStack(spacing: 11) {
                        FoodBadge(food: suggestion.food, size: 43)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.food.name).nibbleFont(size: 14, weight: .semibold)
                            Text("+\(suggestion.focus.grams(in: suggestion.food).compact) g \(suggestion.focus.title.lowercased()) · \(suggestion.food.calories.whole) cal")
                                .nibbleFont(size: 11)
                            Text(suggestion.food.servingText).nibbleFont(size: 10).foregroundStyle(Color.ink)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").nibbleFont(size: 12, weight: .semibold)
                    }.padding(12).background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain).accessibilityHint("Review portion and meal before logging")
            }
            if !insight.suggestions.isEmpty {
                Text("An idea, not an instruction. Check ingredients and choose your portion.").nibbleFont(size: 10).foregroundStyle(Color.ink)
            }
        }.cardSurface(.lilac)
    }

    private var mealPanel: some View {
        VStack(alignment: .leading, spacing: 17) {
            SectionHeading(title: "Across your meals")
            ForEach(Meal.allCases) { meal in
                let mealSnapshot = MacroSnapshot(entries: snapshot.entries.filter { $0.meal == meal }, targets: nil)
                VStack(alignment: .leading, spacing: 9) {
                    NibbleAdaptiveStack(spacing: 8) {
                        Label(meal.title, systemImage: meal.icon).nibbleFont(size: 13, weight: .semibold)
                        Text(mealSnapshot.entries.isEmpty ? "Not logged" : mealSnapshot.isPartial ? "Partial macros" : "\(mealSnapshot.totals.calories.whole) cal")
                            .nibbleFont(size: 10).foregroundStyle(Color.muted)
                    }
                    MacroEnergyStrip(snapshot: mealSnapshot).frame(height: 7)
                    if !mealSnapshot.entries.isEmpty {
                        NibbleAdaptiveStack(spacing: 8) {
                            ForEach(MacroKind.allCases) { macro in
                                Text("\(macro.letter) \(mealSnapshot.knownCount == 0 ? "—" : macro.grams(in: mealSnapshot.totals).compact) g")
                                    .nibbleFont(size: 11, weight: .medium, design: .rounded).frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityLabel("\(macro.title): \(mealSnapshot.knownCount == 0 ? "unknown" : macro.grams(in: mealSnapshot.totals).compact + " grams")")
                            }
                        }
                    }
                }
                if meal != .snack { Divider() }
            }
            Text("Bar colors show each meal’s known macro energy split, not its size.")
                .nibbleFont(size: 10).foregroundStyle(Color.muted)
        }.cardSurface()
    }

    private var contributorPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Where \(focus.title.lowercased()) came from")
            let contributors = snapshot.contributors(to: focus)
            if contributors.isEmpty {
                Text("No known \(focus.title.lowercased()) logged for this day yet.").nibbleFont(size: 13).foregroundStyle(Color.muted)
            }
            ForEach(contributors.prefix(5)) { entry in
                NibbleAdaptiveStack(spacing: 10) {
                    FoodBadge(food: entry.food, size: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.food.name).nibbleFont(size: 13, weight: .medium)
                        Text("\(entry.meal.title) · \(entry.portionDescription)").nibbleFont(size: 10).foregroundStyle(Color.muted)
                    }
                    Text("\((focus.grams(in: entry.food) * entry.servings).compact) g").nibbleFont(size: 13, weight: .semibold)
                }
            }
            if contributors.count > 5 { Text("Top 5 of \(contributors.count) contributions").nibbleFont(size: 10).foregroundStyle(Color.muted) }
        }.cardSurface()
    }
}

struct MacroEnergyStrip: View {
    let snapshot: MacroSnapshot
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(MacroKind.allCases) { macro in
                    macro.color.frame(width: geometry.size.width * snapshot.share(macro))
                }
            }.frame(maxWidth: .infinity, alignment: .leading).background(Color.fog).clipShape(Capsule())
        }.accessibilityHidden(true)
    }
}

struct MacroSplitEditor: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var protein = "25"
    @State private var carbs = "45"
    @State private var fat = "30"
    @State private var error: String?
    private var draft: MacroSplit? {
        guard let p = Int(protein), let c = Int(carbs), let f = Int(fat) else { return nil }
        let split = MacroSplit(protein: p, carbs: c, fat: f)
        return split.isValid ? split : nil
    }
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                HStack {
                    Eyebrow(text: "Your personal mixing desk")
                    Spacer()
                    RoundButton(icon: "xmark", label: "Cancel macro changes") { dismiss() }
                }
                Text("A mix that’s\nyours.").nibbleFont(size: 38, weight: .bold, design: .rounded).tracking(-1.5)
                Text("Set the share of target calories for each macro. Your calorie target stays the same; gram targets update with it.")
                    .nibbleFont(size: 14).foregroundStyle(Color.muted)
                VStack(spacing: 14) {
                    splitInput("Protein", value: $protein, color: .peach)
                    splitInput("Carbs", value: $carbs, color: .lilac)
                    splitInput("Fat", value: $fat, color: .lime)
                }
                if let draft {
                    Label("100% · everything adds up", systemImage: "checkmark.circle.fill").nibbleFont(size: 13, weight: .semibold)
                    if let calories = appState.targets?.calories {
                        let preview = NutritionEngine.macroTargets(calories: calories, split: draft)
                        Text("At \(calories.whole) cal: \(preview.protein.compact) g protein · \(preview.carbs.compact) g carbs · \(preview.fat.compact) g fat")
                            .nibbleFont(size: 13).lineSpacing(4)
                    } else {
                        Text("Saved as a preference. To use gram targets, add a calorie target in You → Tune my plan. You can keep tracking without one.")
                            .nibbleFont(size: 13).foregroundStyle(Color.muted)
                    }
                } else {
                    InlineMessage(text: "Use whole percentages from 1–98 that add up to 100. All three macros need a share.")
                }
                if let error { InlineMessage(text: error) }
                NibbleButton(title: "Save my mix", icon: "checkmark") {
                    guard let draft else { return }
                    if appState.setMacroSplit(draft) { dismiss() }
                    else { error = appState.storageError ?? "Your mix couldn’t be saved. Try again." }
                }.disabled(draft == nil).opacity(draft == nil ? 0.45 : 1)
                Button("Reset draft to 25 / 45 / 30") { protein = "25"; carbs = "45"; fat = "30" }
                    .nibbleFont(size: 13, weight: .medium).buttonStyle(.plain).frame(minHeight: 44)
                Text("This is a planning preference, not a nutrition prescription. These percentages describe energy, not food weight. Changing the mix doesn’t change foods you’ve logged. Historical comparisons use your current plan.")
                    .nibbleFont(size: 12).foregroundStyle(Color.muted).lineSpacing(3)
            }.padding(24).foregroundStyle(Color.ink)
        }.background(Color.canvas).scrollDismissesKeyboard(.interactively)
            .onAppear {
                protein = String(appState.macroSplit.protein)
                carbs = String(appState.macroSplit.carbs)
                fat = String(appState.macroSplit.fat)
            }
    }
    private func splitInput(_ title: String, value: Binding<String>, color: Color) -> some View {
        NibbleAdaptiveStack(spacing: 8) {
            Text(title).nibbleFont(size: 16, weight: .semibold)
            HStack {
            if !typeSize.isAccessibilitySize { Spacer() }
            TextField("25", text: value).numericKeyboard().textFieldStyle(.plain)
                .multilineTextAlignment(.trailing).nibbleFont(size: 28, weight: .bold, design: .rounded)
                .frame(width: typeSize.isAccessibilitySize ? nil : 95).accessibilityLabel("\(title) target percentage")
            Text("%").nibbleFont(size: 16)
            }
        }.padding(20).background(color, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct MacroWeekView: View {
    let week: MacroWeek
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            SectionHeading(title: "Seven days, three colors")
            ScrollView(.horizontal, showsIndicators: false) { HStack(alignment: .top, spacing: 9) {
                ForEach(Array(week.days.enumerated()), id: \.element) { index, day in
                    let snapshot = week.snapshots[index]
                    VStack(spacing: 8) {
                        GeometryReader { geometry in
                            VStack(spacing: 0) {
                                ForEach(MacroKind.allCases) { macro in
                                    macro.color.frame(height: geometry.size.height * snapshot.share(macro))
                                }
                            }.frame(maxHeight: .infinity, alignment: .bottom).background(Color.fog)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }.frame(height: 74)
                        Text(String(day.shortDay.prefix(1))).nibbleFont(size: 10)
                        Text(snapshot.isPartial ? "◐" : snapshot.knownCount == 0 ? "—" : " ").nibbleFont(size: 10)
                    }.frame(width: 36).accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(snapshot.coverageText)\(snapshot.isPartial ? ", partial" : "")")
                        .accessibilityValue(snapshot.knownCount == 0 ? "No macro data" : MacroKind.allCases.map {
                            "\($0.title): \($0.grams(in: snapshot.totals).compact) grams"
                        }.joined(separator: ", "))
                }
            }}.defaultScrollAnchor(.trailing)
            NibbleAdaptiveStack(spacing: 10) {
                ForEach(MacroKind.allCases) { macro in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(macro.title, systemImage: "circle.fill").nibbleFont(size: 10, weight: .medium)
                        Text(week.average(macro).map { "\($0.compact) g" } ?? "—")
                            .nibbleFont(size: 18, weight: .semibold, design: .rounded)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(macro.color, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            Text("Daily known-gram averages across \(week.daysWithMacros) \(week.daysWithMacros == 1 ? "day" : "days") with macro data. Bars show energy proportions, not total intake. Unlogged and calorie-only days are excluded; ◐ marks incomplete macros. Partial logging can lower averages.")
                .nibbleFont(size: 10).foregroundStyle(Color.muted).lineSpacing(3)
        }.foregroundStyle(Color.ink).cardSurface()
    }
}

struct MacroPortionPreview: View {
    @EnvironmentObject private var appState: AppState
    let food: FoodItem
    let servings: Double
    let entry: FoodLogEntry?
    var body: some View {
        let date = entry?.date ?? appState.selectedDate
        let before = MacroSnapshot(entries: appState.entries(on: date), targets: appState.targets)
        if let after = MacroEngine.preview(snapshot: before, food: food, servings: servings, replacing: entry?.id) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "\(date.diaryTitle) · a little preview")
                Text(entry == nil ? "Your day, with this bite." : "Your day, with this change.")
                    .nibbleFont(size: 18, weight: .semibold, design: .rounded)
                ForEach(MacroKind.allCases) { macro in
                    NibbleAdaptiveStack(spacing: 7) {
                        HStack(spacing: 7) {
                        Circle().fill(macro.color).frame(width: 9, height: 9)
                        Text(macro.title).nibbleFont(size: 12)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 7) {
                        Text(before.knownCount == 0 && !before.entries.isEmpty ? "—" : macro.grams(in: before.totals).compact + " g")
                            .foregroundStyle(Color.muted)
                        Image(systemName: "arrow.right").nibbleFont(size: 9)
                        Text(after.knownCount == 0 ? "—" : macro.grams(in: after.totals).compact + " g")
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("macro.preview.after.\(macro.rawValue)")
                        }
                    }.nibbleFont(size: 12, design: .rounded)
                }
                Text(after.isPartial ? "Known grams only. Calorie-only bites remain unknown." : "Preview only. Nothing is logged until you save.")
                    .nibbleFont(size: 10).foregroundStyle(Color.muted)
            }.cardSurface(.fog, padding: 17)
        }
    }
}
