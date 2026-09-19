import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var typeSize
    let onAddFood: (Meal) -> Void
    @State private var showCalendar = false
    @State private var calendarDate = Date()
    @State private var editingEntry: FoodLogEntry?
    @State private var macroFocus: MacroKind?
    private var totals: DailyTotals { appState.selectedTotals }
    private var target: Double? { appState.targets?.calories }
    private var isToday: Bool { Calendar.current.isDateInToday(appState.selectedDate) }
    private var loggedMeals: [Meal] {
        Meal.allCases.filter { meal in appState.selectedEntries.contains { $0.meal == meal } }
    }
    private var week: [Date] {
        (0..<7).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header
                dailySummary
                if appState.selectedEntries.isEmpty { emptyDiary } else { diary }
            }.padding(.horizontal, 23).padding(.top, 20).padding(.bottom, 24)
        }
        .sheet(isPresented: $showCalendar) { calendarSheet }
        .sheet(item: $editingEntry) { entry in
            FoodPortionView(food: entry.food, initialMeal: entry.meal, entry: entry).phoneSheet()
        }
        .sheet(item: $macroFocus) { macro in MacroMixView(initialFocus: macro).phoneSheet() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Button {
                    calendarDate = appState.selectedDate
                    showCalendar = true
                } label: {
                    HStack(spacing: 9) {
                        Text(appState.selectedDate.diaryTitle)
                            .nibbleFont(size: 30, weight: .bold, design: .rounded).tracking(-1)
                        Image(systemName: "chevron.down").nibbleFont(size: 12, weight: .semibold)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityIdentifier("diary.date")
                    .accessibilityLabel("Choose diary date, \(appState.selectedDate.formatted(date: .complete, time: .omitted))")
                if isToday {
                    Text(appState.selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .nibbleFont(size: 12).foregroundStyle(Color.muted)
                } else {
                    Text(appState.selectedDate.formatted(.dateTime.month(.abbreviated).day().year()))
                        .nibbleFont(size: 12).foregroundStyle(Color.muted)
                    Button("Back to today") { appState.selectedDate = Date() }
                        .nibbleFont(size: 13, weight: .semibold).buttonStyle(.plain)
                        .frame(minHeight: 44).accessibilityIdentifier("diary.today")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if !typeSize.isAccessibilitySize {
                HStack(spacing: 8) {
                    if appState.isPreview {
                        Text("DEMO").nibbleFont(size: 8, weight: .bold, design: .monospaced)
                            .padding(6).background(Color.fog, in: Capsule())
                    }
                    Text("nibble.").nibbleFont(size: 22, weight: .black, design: .rounded).tracking(-1)
                        .foregroundStyle(Color.limeDark).accessibilityLabel("Nibble")
                }
            }
        }.foregroundStyle(Color.ink)
    }

    private var dailySummary: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(totals.calories.whole)
                        .accessibilityIdentifier("diary.calories")
                        .nibbleFont(size: 52, weight: .medium, design: .rounded).tracking(-2)
                        .lineLimit(1).minimumScaleFactor(0.7).contentTransition(.numericText())
                    Text("calories logged").nibbleFont(size: 13).foregroundStyle(Color.muted)
                }
                Spacer(minLength: 0)
                if !typeSize.isAccessibilitySize {
                    NibbleMascot(color: .lime, cheerful: true)
                        .frame(width: 68, height: 68).rotationEffect(.degrees(-8))
                }
            }
            if let target {
                VStack(alignment: .leading, spacing: 10) {
                    GeometryReader { g in
                        Capsule().fill(Color.fog)
                        Capsule().fill(Color.limeDark)
                            .frame(width: g.size.width * min(totals.calories / max(target, 1), 1))
                    }.frame(height: 5).accessibilityHidden(true)
                    NibbleAdaptiveStack(spacing: 6) {
                        Text("\(abs(target - totals.calories).whole) \(totals.calories <= target ? "to target" : "above target")")
                            .nibbleFont(size: 12, weight: .medium).frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(target.whole)\(isToday ? " daily target" : " current target")")
                            .nibbleFont(size: 12).foregroundStyle(Color.muted)
                    }
                }
            } else {
                Text("No target. Just a little awareness.").nibbleFont(size: 12).foregroundStyle(Color.muted)
            }
            Rectangle().fill(Color.line).frame(height: 1).accessibilityHidden(true)
            Button { macroFocus = .protein } label: {
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        ForEach(MacroKind.allCases) { macro in
                            Capsule().fill(macro.color).frame(width: 5, height: 18)
                        }
                    }.accessibilityHidden(true)
                    Text("Macro Mix").nibbleFont(size: 13, weight: .semibold)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").nibbleFont(size: 11, weight: .semibold)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Explore your macro mix")
                .accessibilityHint("Protein, carbs, fat, and nutrition details for this day")
                .accessibilityIdentifier("diary.macros")
        }.foregroundStyle(Color.ink).padding(22)
            .background(Color.paper, in: RoundedRectangle(cornerRadius: 26))
    }

    private var emptyDiary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isToday ? "Room for your first bite." : "No food logged this day.")
                .nibbleFont(size: 23, weight: .semibold, design: .rounded).tracking(-0.5)
                .accessibilityIdentifier("diary.empty")
            Text(isToday ? "Tap Add food below. Start with whatever you had." : "Use Add food to fill in this day, or come back to today.")
                .nibbleFont(size: 14).foregroundStyle(Color.muted).lineSpacing(3)
        }.fixedSize(horizontal: false, vertical: true).foregroundStyle(Color.ink).padding(.vertical, 12)
    }

    private var diary: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Your food", detail: "\(appState.selectedEntries.count) \(appState.selectedEntries.count == 1 ? "entry" : "entries")")
            ForEach(loggedMeals) { meal in
                let entries = appState.selectedEntries.filter { $0.meal == meal }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: meal.icon).nibbleFont(size: 13).accessibilityHidden(true)
                        Text(meal.title).nibbleFont(size: 14, weight: .semibold).accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 0)
                        Button { onAddFood(meal) } label: {
                            Image(systemName: "plus").font(.system(size: 14, weight: .medium))
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("Add food to \(meal.title)")
                    }.foregroundStyle(Color.muted)
                    ForEach(entries) { entry in
                        HStack(spacing: 4) {
                            Button { editingEntry = entry } label: {
                                NibbleAdaptiveStack(spacing: 12) {
                                    if !typeSize.isAccessibilitySize { FoodBadge(food: entry.food, size: 36) }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.food.name).nibbleFont(size: 14, weight: .medium)
                                        Text(entry.portionDescription).nibbleFont(size: 11).foregroundStyle(Color.muted)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    Text(entry.calories.whole).nibbleFont(size: 14, weight: .semibold, design: .rounded)
                                }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("Edit \(entry.food.name), \(entry.calories.whole) calories")
                            Menu {
                                Button("Edit portion", systemImage: "pencil") { editingEntry = entry }
                                Button("Have it again", systemImage: "arrow.clockwise") {
                                    appState.addEntry(food: entry.food, meal: meal, servings: entry.servings)
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) { appState.deleteEntry(entry) }
                            } label: {
                                Image(systemName: "ellipsis").frame(width: 44, height: 44)
                            }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Options for \(entry.food.name)")
                        }.padding(.vertical, 10)
                    }
                }.padding(.horizontal, 14).padding(.bottom, 6)
                    .background(Color.paper, in: RoundedRectangle(cornerRadius: 20))
            }
        }.foregroundStyle(Color.ink)
    }

    private var calendarSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Pick a day").nibbleFont(size: 26, weight: .bold, design: .rounded)
                    Spacer()
                    RoundButton(icon: "xmark", label: "Close calendar") { showCalendar = false }
                }
                Text("Recent days").nibbleFont(size: 13, weight: .semibold)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(week, id: \.self) { date in
                            let selected = Calendar.current.isDate(date, inSameDayAs: calendarDate)
                            Button { calendarDate = date } label: {
                                VStack(spacing: 8) {
                                    Text(date.shortDay).nibbleFont(size: 11)
                                    Text(date.formatted(.dateTime.day())).nibbleFont(size: 14, weight: .semibold)
                                    Circle().fill(appState.entries(on: date).isEmpty ? Color.clear : Color.ink).frame(width: 4, height: 4)
                                }.frame(minWidth: 44).padding(8)
                                    .background(selected ? Color.lime : Color.fog, in: RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain)
                                .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                                .accessibilityValue(appState.entries(on: date).isEmpty ? "No entries" : "Food logged")
                                .accessibilityAddTraits(selected ? .isSelected : [])
                                .accessibilityIdentifier("diary.day.\(dayIdentifier(date))")
                        }
                    }
                }.defaultScrollAnchor(.trailing)
                DatePicker("Diary date", selection: $calendarDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }.padding(24)
        }.safeAreaInset(edge: .bottom) {
            NibbleButton(title: "Open \(calendarDate.diaryTitle.lowercased())") {
                appState.selectedDate = calendarDate
                showCalendar = false
            }.padding(24).background(Color.canvas)
        }.foregroundStyle(Color.ink).background(Color.canvas).phoneSheet()
    }

    private func dayIdentifier(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
