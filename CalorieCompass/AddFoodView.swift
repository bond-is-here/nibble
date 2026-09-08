import SwiftUI

struct AddFoodView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var meal: Meal
    @State private var mode = 0
    @State private var filter = 0
    @State private var query = ""
    @State private var barcode = ""
    @State private var selectedFood: FoodItem?
    @State private var showScanner = false
    @State private var showCustom = false
    @State private var lookupTask: Task<Void, Never>?
    @State private var lookingUp = false
    @State private var message: String?
    private let startWithScan: Bool

    init(initialMeal: Meal = .suggested(), startWithScan: Bool = false) {
        _meal = State(initialValue: initialMeal)
        _mode = State(initialValue: startWithScan ? 1 : 0)
        self.startWithScan = startWithScan
    }

    private var foods: [FoodItem] {
        let source = filter == 1 ? appState.recentFoods : filter == 2 ? appState.favoriteFoods : appState.allFoods
        let words = query.split(whereSeparator: \.isWhitespace).map { String($0) }
        return source.filter { food in
            words.allSatisfy { (food.name + " " + (food.brand ?? "")).localizedCaseInsensitiveContains($0) }
        }
    }

    var body: some View {
        Group {
            if let food = selectedFood {
                FoodPortionView(food: food, initialMeal: meal, onClose: { selectedFood = nil }, onLogged: { dismiss() })
            } else if showCustom {
                CustomFoodView(initialName: query, onClose: { showCustom = false }) { food in
                    selectedFood = food
                    showCustom = false
                }
            } else {
                main
            }
        }
        .background(Color.canvas)
        .sheet(isPresented: $showScanner) {
            ZStack(alignment: .topTrailing) {
                BarcodeScannerView { code in
                    showScanner = false
                    barcode = code
                    lookup()
                }
                RoundButton(icon: "xmark", label: "Close scanner", fill: .white) { showScanner = false }.padding(20)
            }.phoneSheet()
        }
        .onDisappear { lookupTask?.cancel() }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "\(appState.selectedDate.diaryTitle) / \(meal.title)")
                    Text("What’s the bite?").font(.system(size: 30, weight: .bold, design: .rounded)).tracking(-1.2)
                }
                Spacer()
                RoundButton(icon: "xmark", label: "Close add food") { dismiss() }
            }
            MealSelector(selected: $meal)
            HStack(spacing: 8) {
                modeButton("Find a food", icon: "magnifyingglass", value: 0)
                modeButton("Scan barcode", icon: "barcode", value: 1)
                Button { showCustom = true } label: {
                    Image(systemName: "square.and.pencil").font(.system(size: 18)).frame(width: 48, height: 48)
                        .background(Color.fog, in: RoundedRectangle(cornerRadius: 15))
                }.buttonStyle(.plain).accessibilityLabel("Enter calories or create a food")
            }
            if let error = appState.storageError { InlineMessage(text: error) }
            if mode == 0 { search }
            else { barcodePanel }
        }
        .foregroundStyle(Color.ink).padding(23).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func modeButton(_ title: String, icon: String, value: Int) -> some View {
        Button {
            mode = value
            message = nil
            if value == 0 { lookupTask?.cancel(); lookingUp = false }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title)
            }.font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 48)
                .background(mode == value ? Color.lime : Color.fog, in: RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain).accessibilityAddTraits(mode == value ? .isSelected : [])
    }

    private var search: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.muted)
                TextField("Yogurt, coffee, last night’s pasta…", text: $query).textFieldStyle(.plain).font(.system(size: 13))
                    .accessibilityLabel("Search your foods")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.muted) }
                        .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }.padding(15).background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line))
            HStack(spacing: 20) {
                ForEach(Array(["All foods", "Recent", "Favorites"].enumerated()), id: \.offset) { index, title in
                    Button { filter = index } label: {
                        VStack(spacing: 7) {
                            Text(title).font(.system(size: 12, weight: filter == index ? .semibold : .regular))
                                .foregroundStyle(filter == index ? Color.ink : Color.muted)
                            Capsule().fill(filter == index ? Color.ink : Color.clear).frame(height: 2)
                        }
                    }.buttonStyle(.plain).accessibilityAddTraits(filter == index ? .isSelected : [])
                }
                Spacer()
            }
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    if foods.isEmpty {
                        VStack(spacing: 12) {
                            NibbleMascot(color: .lilac).frame(width: 85, height: 85).rotationEffect(.degrees(-12))
                            Text(filter == 2 && query.isEmpty ? "Save your go-to bites." : "Let’s make it yours.").font(.system(size: 19, weight: .semibold, design: .rounded))
                            Text(filter == 2 && query.isEmpty ? "Tap the star beside any food to find it here." : "No matches yet. Add the calories from a label or your own estimate.")
                                .font(.system(size: 13)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                        }.padding(.vertical, 30)
                    }
                    ForEach(foods, id: \.stableKey) { food in foodRow(food) }
                    Button { showCustom = true } label: {
                        HStack(spacing: 11) {
                            Image(systemName: "plus").frame(width: 42, height: 42).background(Color.lime, in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Make a food").font(.system(size: 14, weight: .semibold))
                                Text("Just calories is okay, too.").font(.system(size: 11)).foregroundStyle(Color.muted)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }.padding(.vertical, 14).padding(.horizontal, 8).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Text("Starter foods are estimates. Use a barcode or label for exact product details.")
                        .font(.system(size: 10)).foregroundStyle(Color.muted).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                }
            }
        }
    }

    private func foodRow(_ food: FoodItem) -> some View {
        HStack(spacing: 8) {
            Button { selectedFood = food } label: {
                HStack(spacing: 11) {
                    FoodBadge(food: food)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        Text("\(food.servingText) · \(food.calories.whole) cal").font(.system(size: 11)).foregroundStyle(Color.muted).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Choose \(food.name), \(food.servingText), \(food.calories.whole) calories")
            Button { appState.toggleFavorite(food) } label: {
                Image(systemName: appState.isFavorite(food) ? "star.fill" : "star")
                    .font(.system(size: 14)).foregroundStyle(appState.isFavorite(food) ? Color.limeDark : Color.muted)
                    .frame(width: 40, height: 44)
            }.buttonStyle(.plain).accessibilityLabel(appState.isFavorite(food) ? "Unfavorite \(food.name)" : "Favorite \(food.name)")
            Button {
                if appState.addEntry(food: food, meal: meal, servings: 1) { NibbleHaptics.tap(); dismiss() }
            } label: {
                Image(systemName: "plus").font(.system(size: 15, weight: .medium))
                    .frame(width: 40, height: 44).background(Color.lime, in: Circle())
            }.buttonStyle(.plain).accessibilityLabel("Quick add \(food.name), \(food.servingText)")
        }.padding(.vertical, 10)
    }

    private var barcodePanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28).fill(Color.lilac)
                    VStack(spacing: 14) {
                        Image(systemName: "barcode.viewfinder").font(.system(size: 52, weight: .light))
                        Text("Point. Scan. Nibble.").font(.system(size: 23, weight: .semibold, design: .rounded))
                        Text("The label does the talking.").font(.system(size: 13)).foregroundStyle(Color.muted)
                    }.padding(.vertical, 35)
                }
                NibbleButton(title: "Open camera", icon: "camera") { showScanner = true }
                HStack {
                    Rectangle().fill(Color.line).frame(height: 1)
                    Text("OR TYPE THE BARCODE").font(.system(size: 9, weight: .medium, design: .monospaced)).fixedSize()
                    Rectangle().fill(Color.line).frame(height: 1)
                }.foregroundStyle(Color.muted)
                HStack(spacing: 10) {
                    TextField("e.g. 3017620422003", text: $barcode).numericKeyboard().textFieldStyle(.plain).font(.system(size: 15))
                        .accessibilityLabel("Barcode number")
                    Button { lookup() } label: {
                        if lookingUp { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.right").font(.system(size: 16, weight: .semibold)) }
                    }.frame(width: 44, height: 44).background(Color.lime, in: Circle())
                        .buttonStyle(.plain).disabled(lookingUp || barcode.isEmpty).accessibilityLabel("Look up barcode")
                }.padding(10).background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                if let message {
                    InlineMessage(text: message)
                    Button("Enter the label instead") { showCustom = true }.font(.system(size: 13, weight: .semibold)).buttonStyle(.plain)
                }
                Text("Product data from Open Food Facts. Check it against the package before logging.")
                    .font(.system(size: 11)).foregroundStyle(Color.muted)
            }
        }
    }

    private func lookup() {
        lookupTask?.cancel()
        lookingUp = true
        message = nil
        let code = barcode
        lookupTask = Task { @MainActor in
            defer { if !Task.isCancelled { lookingUp = false } }
            do {
                let food = try await OpenFoodFactsClient().lookup(barcode: code)
                guard !Task.isCancelled else { return }
                selectedFood = food
            } catch {
                guard !Task.isCancelled else { return }
                message = error.localizedDescription
            }
        }
    }
}

struct FoodPortionView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let food: FoodItem
    var entry: FoodLogEntry?
    var onClose: (() -> Void)?
    var onLogged: (() -> Void)?
    @State private var meal: Meal
    @State private var amount: String
    @State private var error: String?

    init(food: FoodItem, initialMeal: Meal, entry: FoodLogEntry? = nil, onClose: (() -> Void)? = nil, onLogged: (() -> Void)? = nil) {
        self.food = food
        self.entry = entry
        self.onClose = onClose
        self.onLogged = onLogged
        _meal = State(initialValue: initialMeal)
        _amount = State(initialValue: ((entry?.servings ?? 1) * (food.isPerHundred ? 100 : 1)).inputString)
    }

    private var servings: Double? {
        guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")), value.isFinite else { return nil }
        let servings = value / (food.isPerHundred ? 100 : 1)
        return (0.01...100).contains(servings) ? servings : nil
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 23) {
                HStack {
                    Eyebrow(text: entry == nil ? "Make it your portion" : "Edit this bite")
                    Spacer()
                    RoundButton(icon: "xmark", label: "Close portion") { close() }
                }
                HStack(alignment: .center, spacing: 18) {
                    FoodBadge(food: food, size: 78)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(food.name).font(.system(size: 27, weight: .bold, design: .rounded)).tracking(-0.8)
                        if let brand = food.brand { Text(brand).font(.system(size: 12)).foregroundStyle(Color.muted) }
                        Text("Nutrition for \(food.servingText)").font(.system(size: 12, weight: .medium))
                    }
                }
                MealSelector(selected: $meal)
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "How much did you have?")
                    HStack(alignment: .firstTextBaseline) {
                        TextField("1", text: $amount).numericKeyboard().textFieldStyle(.plain)
                            .font(.system(size: 50, weight: .medium, design: .rounded)).accessibilityLabel("Portion amount")
                        Text(food.quantityUnit).font(.system(size: 16)).foregroundStyle(Color.muted)
                    }
                    HStack(spacing: 8) {
                        ForEach(food.isPerHundred ? [25.0, 50, 100, 200] : [0.5, 1, 1.5, 2], id: \.self) { value in
                            Button { amount = value.inputString } label: {
                                Text(value.compact).font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity).frame(height: 43).background(Color.white, in: Capsule())
                            }.buttonStyle(.plain).accessibilityLabel("\(value.compact) \(food.quantityUnit)")
                        }
                    }
                }.cardSurface(.fog)
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(((servings ?? 0) * food.calories).whole).font(.system(size: 44, weight: .semibold, design: .rounded)).tracking(-2)
                        Text("calories").font(.system(size: 15))
                        Spacer()
                        Image(systemName: "sparkle").font(.system(size: 24))
                    }
                    if food.hasMacros {
                        HStack(spacing: 8) {
                            portionMacro("Protein", value: food.protein, color: .peach)
                            portionMacro("Carbs", value: food.carbs, color: .lilac)
                            portionMacro("Fat", value: food.fat, color: .lime)
                        }
                    } else {
                        Text("Calories-only entry. Macros aren’t included.").font(.system(size: 12)).foregroundStyle(Color.muted)
                    }
                }
                if let error { InlineMessage(text: error) }
                if let storageError = appState.storageError { InlineMessage(text: storageError) }
                if let servings { MacroPortionPreview(food: food, servings: servings, entry: entry) }
                NibbleButton(title: entry == nil ? "Add to \(meal.title.lowercased())" : "Save changes", icon: "checkmark") {
                    guard let servings else { error = "Enter an amount above zero, up to 100 servings."; return }
                    let saved: Bool
                    if let entry { saved = appState.editEntry(entry, meal: meal, servings: servings) }
                    else { saved = appState.addEntry(food: food, meal: meal, servings: servings) }
                    if saved {
                        if let onLogged { onLogged() } else { dismiss() }
                    }
                }.opacity(servings == nil ? 0.5 : 1).accessibilityIdentifier("portion.save")
                if food.source == .openFoodFacts {
                    Text("From Open Food Facts · check the label.").font(.system(size: 10)).foregroundStyle(Color.muted)
                }
            }.foregroundStyle(Color.ink).padding(24)
        }.background(Color.canvas).scrollDismissesKeyboard(.interactively)
    }

    private func close() { if let onClose { onClose() } else { dismiss() } }
    private func portionMacro(_ title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 11))
            Text("\((value * (servings ?? 0)).compact) g").font(.system(size: 16, weight: .semibold, design: .rounded))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(13).background(color, in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct CustomFoodView: View {
    let onClose: () -> Void
    let onCreate: (FoodItem) -> Void
    @State private var name: String
    @State private var calories = ""
    @State private var portion = "1 serving"
    @State private var addMacros = false
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var error: String?

    init(initialName: String, onClose: @escaping () -> Void, onCreate: @escaping (FoodItem) -> Void) {
        self.onClose = onClose
        self.onCreate = onCreate
        _name = State(initialValue: initialName)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("Make a food.").font(.system(size: 30, weight: .bold, design: .rounded)).tracking(-1)
                    Spacer()
                    RoundButton(icon: "xmark", label: "Cancel custom food", action: onClose)
                }
                Text("A label, a recipe, or your best estimate. Give it a name and you can use it again.")
                    .font(.system(size: 14)).foregroundStyle(Color.muted)
                LabeledInput(label: "What did you have?", placeholder: "Grandma’s lasagna", text: $name, numeric: false)
                HStack(alignment: .top, spacing: 12) {
                    LabeledInput(label: "Calories", placeholder: "350", text: $calories, unit: "cal")
                    LabeledInput(label: "Portion", placeholder: "1 slice", text: $portion, numeric: false)
                }
                Toggle("Add macros", isOn: $addMacros).font(.system(size: 14, weight: .semibold)).tint(Color.limeDark)
                if addMacros {
                    HStack(spacing: 10) {
                        LabeledInput(label: "Protein", placeholder: "0", text: $protein, unit: "g")
                        LabeledInput(label: "Carbs", placeholder: "0", text: $carbs, unit: "g")
                        LabeledInput(label: "Fat", placeholder: "0", text: $fat, unit: "g")
                    }
                }
                if let error { InlineMessage(text: error) }
                NibbleButton(title: "Choose a portion", icon: "arrow.right", action: create)
                Text("Saved automatically when you log it.").font(.system(size: 11)).foregroundStyle(Color.muted)
            }.padding(24).foregroundStyle(Color.ink)
        }.background(Color.canvas).scrollDismissesKeyboard(.interactively)
    }

    private func create() {
        func number(_ string: String) -> Double? { Double(string.replacingOccurrences(of: ",", with: ".")) }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let serving = portion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !serving.isEmpty, let cal = number(calories), cal.isFinite, (0...10000).contains(cal) else {
            error = "Add a food name, portion, and valid calories (0–10,000)."; return
        }
        var p = 0.0, c = 0.0, f = 0.0
        if addMacros {
            guard let pv = number(protein), let cv = number(carbs), let fv = number(fat),
                  [pv, cv, fv].allSatisfy({ $0.isFinite && (0...1000).contains($0) }) else {
                error = "Enter all three macros. Use 0 if the label says zero."; return
            }
            p = pv; c = cv; f = fv
        }
        onCreate(FoodItem(name: title, brand: "Your food", servingText: serving, calories: cal, protein: p, carbs: c, fat: f, source: .custom, macrosComplete: addMacros))
    }
}
