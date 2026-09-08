import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    private let isEditing: Bool
    @State private var setup: Bool
    @State private var planMode = 0
    @State private var units: DisplayUnits = .imperial
    @State private var age = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var goalWeight = ""
    @State private var target = ""
    @State private var sex: Sex = .unspecified
    @State private var activity: ActivityLevel = .lightlyActive
    @State private var goal: Goal = .maintain
    @State private var error: String?
    @State private var loaded = false

    init(isEditing: Bool = false) {
        self.isEditing = isEditing
        _setup = State(initialValue: isEditing)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                if setup { setupContent } else { welcome }
            }.padding(25).frame(maxWidth: 480)
                .frame(maxWidth: .infinity, alignment: .top)
        }.background(Color.canvas).scrollDismissesKeyboard(.interactively)
            .onAppear(perform: load)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 27) {
            HStack {
                Text("nibble.").font(.system(size: 36, weight: .black, design: .rounded)).tracking(-2)
                Spacer()
                Eyebrow(text: "A little lighter")
            }.padding(.top, 12)
            ZStack {
                RoundedRectangle(cornerRadius: 110).fill(Color.lilac).rotationEffect(.degrees(-8))
                    .frame(width: 240, height: 255)
                NibbleMascot(color: .lime, cheerful: true).frame(width: 200, height: 200).rotationEffect(.degrees(-13)).offset(x: -3, y: 5)
                Text("tiny effort.").font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 15).padding(.vertical, 10).background(.white, in: Capsule())
                    .rotationEffect(.degrees(9)).offset(x: 88, y: -104)
                Text("big little wins.").font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 15).padding(.vertical, 10).background(.white, in: Capsule())
                    .rotationEffect(.degrees(-6)).offset(x: -64, y: 106)
                Text("✳").font(.system(size: 44)).offset(x: -132, y: -69)
            }.frame(maxWidth: .infinity).frame(height: 300).padding(.top, 10)
            VStack(alignment: .leading, spacing: 13) {
                Text("Less logging.\nMore living.")
                    .font(.system(size: 48, weight: .semibold, design: .rounded)).tracking(-2.7)
                    .lineSpacing(-3).fixedSize(horizontal: false, vertical: true)
                Text("A food diary for real life. Find your balance, remember your favorites, and get on with your day.")
                    .font(.system(size: 16)).foregroundStyle(Color.muted).lineSpacing(4)
            }
            VStack(spacing: 18) {
                NibbleButton(title: "Let’s make it yours") { withAnimation { setup = true } }
                Button("Just start logging") { _ = appState.startTracking() }
                    .font(.system(size: 14, weight: .medium)).buttonStyle(.plain)
            }
            HStack(spacing: 7) {
                Image(systemName: "lock").font(.system(size: 10))
                Text("No account. Your diary stays on this device.").font(.system(size: 10))
            }.foregroundStyle(Color.muted).frame(maxWidth: .infinity)
        }.foregroundStyle(Color.ink)
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Eyebrow(text: isEditing ? "Your plan, your rules" : "A minute, then you’re in")
                Spacer()
                RoundButton(icon: "xmark", label: "Close setup") {
                    if isEditing { dismiss() } else { setup = false }
                }
            }
            Text("Find your\nkind of balance.").font(.system(size: 35, weight: .semibold, design: .rounded)).tracking(-1.5)
            Picker("Plan type", selection: $planMode) {
                Text("Estimate for me").tag(0)
                Text("Set my own").tag(1)
                Text("Just track").tag(2)
            }.pickerStyle(.segmented)
            if planMode == 0 { estimateForm }
            else if planMode == 1 {
                Text("Already have a daily target? Bring it with you.").font(.system(size: 15)).foregroundStyle(Color.muted)
                LabeledInput(label: "Daily calorie target", placeholder: "e.g. 2100", text: $target, unit: "cal")
                Text("Macro targets start at 25% protein, 45% carbs, and 30% fat. You can customize the mix later in You.")
                    .font(.system(size: 12)).foregroundStyle(Color.muted)
            } else {
                NibbleMascot(color: .lilac).frame(width: 100, height: 100).rotationEffect(.degrees(-10))
                Text("Awareness is a great place to start. Log calories and macros without a daily target.")
                    .font(.system(size: 16)).foregroundStyle(Color.muted).lineSpacing(4)
            }
            if let error { InlineMessage(text: error) }
            if let error = appState.storageError { InlineMessage(text: error) }
            NibbleButton(title: isEditing ? "Save my plan" : "Let’s nibble", icon: "arrow.right", action: save)
        }.foregroundStyle(Color.ink)
    }

    private var estimateForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Your starting point").font(.system(size: 15, weight: .semibold))
                Spacer()
                Picker("Units", selection: Binding(get: { units }, set: { new in
                    convertUnits(from: units, to: new)
                    units = new
                })) {
                    ForEach(DisplayUnits.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).frame(width: 150)
            }
            HStack(alignment: .top, spacing: 12) {
                LabeledInput(label: "Height", placeholder: units == .metric ? "170" : "67", text: $height, unit: units == .metric ? "cm" : "in")
                LabeledInput(label: "Weight", placeholder: units == .metric ? "70" : "154", text: $weight, unit: units == .metric ? "kg" : "lb")
                LabeledInput(label: "Age", placeholder: "30", text: $age)
            }
            menuRow("Formula", selection: $sex, values: Sex.allCases, title: { $0.title })
            if sex == .unspecified {
                Text("Midpoint averages the male and female formula estimates.").font(.system(size: 10)).foregroundStyle(Color.muted)
            }
            menuRow("Movement", selection: $activity, values: ActivityLevel.allCases, title: { $0.title })
            menuRow("Direction", selection: $goal, values: Goal.allCases, title: { $0.title })
            if goal != .maintain {
                LabeledInput(label: "Goal weight (optional)", placeholder: "A point to work toward", text: $goalWeight, unit: units == .metric ? "kg" : "lb")
            }
            if let profile = draftProfile, profile.isValid {
                let targets = NutritionEngine.targets(for: profile)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: "Your starting estimate", color: .ink)
                        Text("\(targets.calories.whole) cal / day").font(.system(size: 23, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                }.cardSurface(.lime, padding: 18)
            }
            Text("Estimates are for adults, excluding pregnancy and breastfeeding. They’re a starting point, not a prescription.")
                .font(.system(size: 11)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func menuRow<T: Hashable & Identifiable>(_ label: String, selection: Binding<T>, values: [T], title: @escaping (T) -> String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(Color.muted)
            Spacer()
            Picker(label, selection: selection) {
                ForEach(values) { Text(title($0)).tag($0) }
            }.labelsHidden().pickerStyle(.menu)
        }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 14))
    }

    private var draftProfile: UserProfile? {
        func value(_ string: String) -> Double? { Double(string.replacingOccurrences(of: ",", with: ".")) }
        guard let h = value(height), let w = value(weight), let a = Int(age) else { return nil }
        let kg = units == .metric ? w : NutritionEngine.poundsToKilograms(w)
        let goalInput = goal == .maintain || goalWeight.isEmpty ? w : (value(goalWeight) ?? .nan)
        return UserProfile(
            heightCentimeters: units == .metric ? h : NutritionEngine.inchesToCentimeters(h),
            weightKilograms: kg, age: a, sex: sex, activity: activity, goal: goal,
            goalWeightKilograms: units == .metric ? goalInput : NutritionEngine.poundsToKilograms(goalInput),
            displayUnits: units
        )
    }

    private func save() {
        error = nil
        var success = false
        switch planMode {
        case 0:
            guard let profile = draftProfile, profile.isValid else {
                error = "Check your details: age 18–100, height 120–230 cm (47–90 in), and weight 35–300 kg (77–661 lb)."; return
            }
            if !goalWeight.isEmpty && ((goal == .lose && profile.goalWeightKilograms >= profile.weightKilograms) || (goal == .gain && profile.goalWeightKilograms <= profile.weightKilograms)) {
                error = "Choose a goal weight that matches your direction."; return
            }
            success = appState.startTracking(profile: profile, units: units)
        case 1:
            guard let calories = Double(target.replacingOccurrences(of: ",", with: ".")), calories.isFinite, (1000...6000).contains(calories) else {
                error = "Enter your existing daily target, between 1,000 and 6,000 calories."; return
            }
            success = appState.startTracking(profile: appState.profile, target: calories, units: units)
        default:
            success = appState.startTracking(units: units)
        }
        if success && isEditing { dismiss() }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        units = appState.archive.units
        if let targetValue = appState.archive.calorieTarget { target = targetValue.inputString; planMode = 1 }
        else if appState.hasStarted && appState.profile == nil { planMode = 2 }
        if let profile = appState.profile {
            height = (units == .metric ? profile.heightCentimeters : profile.heightCentimeters / 2.54).shortInput
            weight = (units == .metric ? profile.weightKilograms : profile.weightPounds).shortInput
            goalWeight = (units == .metric ? profile.goalWeightKilograms : profile.goalWeightPounds).shortInput
            age = String(profile.age)
            sex = profile.sex; activity = profile.activity; goal = profile.goal
        }
    }

    private func convertUnits(from old: DisplayUnits, to new: DisplayUnits) {
        guard old != new else { return }
        if let h = Double(height.replacingOccurrences(of: ",", with: ".")) { height = (new == .metric ? h * 2.54 : h / 2.54).shortInput }
        if let w = Double(weight.replacingOccurrences(of: ",", with: ".")) { weight = (new == .metric ? w / 2.20462 : w * 2.20462).shortInput }
        if let w = Double(goalWeight.replacingOccurrences(of: ",", with: ".")) { goalWeight = (new == .metric ? w / 2.20462 : w * 2.20462).shortInput }
    }
}
