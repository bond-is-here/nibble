import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onAddFood: (Meal) -> Void
    let onScan: () -> Void
    @State private var showCalendar = false
    @State private var editingEntry: FoodLogEntry?
    @State private var selectedFood: FoodItem?
    @State private var mascotTilt = false
    @State private var macroFocus: MacroKind?
    private var totals: DailyTotals { appState.selectedTotals }
    private var target: Double? { appState.targets?.calories }
    private var week: [Date] {
        (0..<7).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 23) {
                header
                dates
                calorieCard
                MacroMixCard(snapshot: MacroSnapshot(entries: appState.selectedEntries, targets: appState.targets)) { macroFocus = $0 }
                usuals
                diary
                HStack {
                    Spacer()
                    Text("A little awareness. A lot of living.").font(.system(size: 11)).foregroundStyle(Color.muted)
                    Spacer()
                }.padding(.vertical, 8)
            }.padding(.horizontal, 23).padding(.top, 16).padding(.bottom, 20)
        }
        .sheet(isPresented: $showCalendar) {
            VStack(spacing: 22) {
                HStack {
                    Text("Pick a day").font(.system(size: 26, weight: .bold, design: .rounded))
                    Spacer()
                    RoundButton(icon: "xmark", label: "Close calendar") { showCalendar = false }
                }
                DatePicker("Diary date", selection: $appState.selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                NibbleButton(title: "Open \(appState.selectedDate.diaryTitle.lowercased())") { showCalendar = false }
            }.padding(24).background(Color.canvas).phoneSheet()
        }
        .sheet(item: $editingEntry) { entry in
            FoodPortionView(food: entry.food, initialMeal: entry.meal, entry: entry).phoneSheet()
        }
        .sheet(item: $selectedFood) { food in
            FoodPortionView(food: food, initialMeal: .suggested()).phoneSheet()
        }
        .sheet(item: $macroFocus) { macro in MacroMixView(initialFocus: macro).phoneSheet() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 3) {
                Text("nibble").font(.system(size: 34, weight: .black, design: .rounded)).tracking(-2.2)
                Circle().fill(Color.limeDark).frame(width: 7, height: 7).offset(y: 9)
            }.foregroundStyle(Color.ink).accessibilityLabel("Nibble")
            Spacer()
            if appState.isPreview {
                Text("DEMO").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1)
                    .padding(.horizontal, 8).padding(.vertical, 5).background(Color.fog, in: Capsule())
            }
            RoundButton(icon: "barcode.viewfinder", label: "Scan a food barcode", fill: .white, action: onScan)
        }
    }

    private var dates: some View {
        VStack(spacing: 13) {
            HStack {
                Button { showCalendar = true } label: {
                    HStack(spacing: 7) {
                        Text(appState.selectedDate.diaryTitle).font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    }.foregroundStyle(Color.ink)
                }.buttonStyle(.plain)
                Spacer()
                Text(appState.selectedDate.formatted(.dateTime.month(.wide).year()).uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.3).foregroundStyle(Color.muted)
            }
            HStack(spacing: 8) {
                ForEach(week, id: \.self) { date in
                    let selected = Calendar.current.isDate(date, inSameDayAs: appState.selectedDate)
                    Button { withAnimation(.easeInOut(duration: 0.2)) { appState.selectedDate = date } } label: {
                        VStack(spacing: 7) {
                            Text(String(date.shortDay.prefix(1))).font(.system(size: 10, weight: .medium))
                                .foregroundStyle(selected ? Color.ink : Color.muted)
                            Text(date.formatted(.dateTime.day())).font(.system(size: 13, weight: .semibold))
                            Circle().fill(!appState.entries(on: date).isEmpty ? Color.ink : Color.clear).frame(width: 3, height: 3)
                        }.frame(maxWidth: .infinity).padding(.vertical, 9)
                            .foregroundStyle(Color.ink)
                            .background(selected ? Color.lime : Color.clear, in: Capsule())
                            .contentShape(Capsule())
                    }.buttonStyle(.plain)
                        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var calorieCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Eyebrow(text: "Your daily bite", color: .ink)
                Spacer()
                Text("✳").font(.system(size: 20)).foregroundStyle(Color.ink)
            }
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(totals.calories.whole)
                        .accessibilityIdentifier("diary.calories")
                        .font(.system(size: 62, weight: .medium, design: .rounded)).tracking(-4)
                        .lineLimit(1).minimumScaleFactor(0.7).contentTransition(.numericText())
                    Text("calories enjoyed").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.ink.opacity(0.7))
                }
                Spacer(minLength: 8)
                NibbleMascot(color: .white.opacity(0.8), cheerful: !appState.selectedEntries.isEmpty)
                    .frame(width: 112, height: 112)
                    .rotationEffect(.degrees(mascotTilt ? 8 : -7))
                    .onTapGesture {
                        guard !reduceMotion else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.35)) { mascotTilt.toggle() }
                        NibbleHaptics.tap()
                    }
            }
            if let target {
                GeometryReader { g in
                    Capsule().fill(Color.ink.opacity(0.1))
                    Capsule().fill(Color.ink).frame(width: g.size.width * min(totals.calories / max(target, 1), 1))
                }.frame(height: 7).accessibilityHidden(true)
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 4) {
                        Text(abs(target - totals.calories).whole).font(.system(size: 16, weight: .bold, design: .rounded))
                        Text(totals.calories <= target ? "left today" : "above target").font(.system(size: 12))
                    }
                    Spacer()
                    Text("\(target.whole) goal").font(.system(size: 12)).foregroundStyle(Color.ink.opacity(0.65))
                }
            } else {
                Text("Just noticing. No target needed.").font(.system(size: 13, weight: .medium))
                    .padding(.top, 5)
            }
        }
        .foregroundStyle(Color.ink)
        .padding(23).background(Color.lime, in: RoundedRectangle(cornerRadius: 30))
    }

    private var usuals: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeading(title: appState.recentFoods.isEmpty ? "Easy first bites" : "Your usuals", detail: "one tap, one serving")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(appState.quickFoods, id: \.stableKey) { food in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Button { selectedFood = food } label: {
                                    Text(food.emoji).font(.system(size: 27))
                                }.buttonStyle(.plain).accessibilityLabel("Adjust \(food.name) portion")
                                Spacer()
                                Button {
                                    if appState.addEntry(food: food, meal: .suggested(), servings: 1) { NibbleHaptics.tap() }
                                } label: {
                                    Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                                        .frame(width: 36, height: 36).background(Color.canvas, in: Circle())
                                }.buttonStyle(.plain).accessibilityLabel("Log \(food.name), \(food.servingText)")
                            }
                            Button { selectedFood = food } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(food.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                    Text("\(food.calories.whole) cal · \(food.servingText)").font(.system(size: 9)).foregroundStyle(Color.muted).lineLimit(1)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                        }.foregroundStyle(Color.ink).padding(13).frame(width: 150)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
        }
    }

    private var diary: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "On your plate", detail: "\(appState.selectedEntries.count) bites logged")
            ForEach(Meal.allCases) { meal in
                let entries = appState.selectedEntries.filter { $0.meal == meal }
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: meal.icon).font(.system(size: 14, weight: .medium)).frame(width: 20)
                        Text(meal.title).font(.system(size: 14, weight: .semibold))
                        Spacer()
                        if !entries.isEmpty {
                            Text(entries.reduce(0) { $0 + $1.calories }.whole + " cal").font(.system(size: 11)).foregroundStyle(Color.muted)
                        }
                        Button { onAddFood(meal) } label: {
                            Image(systemName: "plus").font(.system(size: 14, weight: .medium)).frame(width: 38, height: 40)
                        }.buttonStyle(.plain).accessibilityLabel("Add food to \(meal.title)")
                    }
                    ForEach(entries) { entry in
                        HStack(spacing: 11) {
                            Button { editingEntry = entry } label: {
                                HStack(spacing: 11) {
                                    FoodBadge(food: entry.food, size: 39)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.food.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                        Text(entry.portionDescription).font(.system(size: 10)).foregroundStyle(Color.muted)
                                    }
                                    Spacer(minLength: 4)
                                    Text(entry.calories.whole).font(.system(size: 13, weight: .semibold, design: .rounded))
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("Edit \(entry.food.name), \(entry.calories.whole) calories")
                            Menu {
                                Button("Edit portion", systemImage: "pencil") { editingEntry = entry }
                                Button("Have it again", systemImage: "arrow.clockwise") {
                                    appState.addEntry(food: entry.food, meal: meal, servings: entry.servings)
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) { appState.deleteEntry(entry) }
                            } label: {
                                Image(systemName: "ellipsis").frame(width: 30, height: 40)
                            }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Options for \(entry.food.name)")
                        }.padding(.vertical, 10)
                    }
                    if entries.isEmpty {
                        Button { onAddFood(meal) } label: {
                            Text("Add a little something").font(.system(size: 12)).foregroundStyle(Color.muted)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 10).padding(.top, 3)
                        }.buttonStyle(.plain)
                    }
                }.foregroundStyle(Color.ink).padding(.horizontal, 16).padding(.vertical, 5)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
            }
        }
    }
}
