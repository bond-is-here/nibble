import SwiftUI

struct LogView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedDay = Date()
    private var days: [Date] { (0..<7).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) } }
    private var loggedDays: [Date] { days.filter { !appState.entries(on: $0).isEmpty } }
    private var average: Double {
        guard !loggedDays.isEmpty else { return 0 }
        return loggedDays.reduce(0) { $0 + DailyTotals(entries: appState.entries(on: $1)).calories } / Double(loggedDays.count)
    }
    private var maxCalories: Double {
        max(1, days.map { DailyTotals(entries: appState.entries(on: $0)).calories }.max() ?? 1)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Eyebrow(text: "The bigger picture")
                        Text("Little by little.").nibbleFont(size: 33, weight: .semibold, design: .rounded).tracking(-1.3)
                    }
                    Spacer()
                    Image(systemName: "sparkle").nibbleFont(size: 25)
                }
                VStack(alignment: .leading, spacing: 22) {
                    NibbleAdaptiveStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 7) {
                            Eyebrow(text: "This week", color: .ink)
                            Text("\(loggedDays.count) / 7").nibbleFont(size: 44, weight: .semibold, design: .rounded).tracking(-2)
                            Text("days you checked in").nibbleFont(size: 13)
                        }
                        NibbleMascot(color: .white.opacity(0.7), cheerful: true).frame(width: 101, height: 101).rotationEffect(.degrees(12))
                    }
                    Text("No streak to lose. Every entry is a little more awareness.")
                        .nibbleFont(size: 13).foregroundStyle(Color.ink.opacity(0.7))
                }.cardSurface(.lilac)
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeading(title: "Your week in bites")
                    ScrollView(.horizontal, showsIndicators: false) { HStack(alignment: .bottom, spacing: 8) {
                        ForEach(days, id: \.self) { day in
                            let total = DailyTotals(entries: appState.entries(on: day)).calories
                            let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                            Button { selectedDay = day } label: {
                                VStack(spacing: 11) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSelected ? Color.ink : total > 0 ? Color.lime : Color.fog)
                                        .frame(height: total > 0 ? max(10, 115 * total / maxCalories) : 5)
                                        .frame(height: 125, alignment: .bottom)
                                    Text(String(day.shortDay.prefix(1))).nibbleFont(size: 11, weight: isSelected ? .bold : .regular)
                                        .foregroundStyle(isSelected ? Color.ink : Color.muted)
                                }.frame(width: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("\(day.shortDay), \(total.whole) calories")
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }}.defaultScrollAnchor(.trailing)
                    NibbleAdaptiveStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(loggedDays.isEmpty ? "—" : average.whole).nibbleFont(size: 23, weight: .semibold, design: .rounded)
                                .accessibilityIdentifier("patterns.average")
                            Text("average on logged days").nibbleFont(size: 11).foregroundStyle(Color.muted)
                        }
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("\(appState.entries.filter { entry in days.contains { Calendar.current.isDate(entry.date, inSameDayAs: $0) } }.count)")
                                .nibbleFont(size: 23, weight: .semibold, design: .rounded)
                            Text("bites this week").nibbleFont(size: 11).foregroundStyle(Color.muted)
                        }
                    }.padding(.top, 3)
                    Text("Unlogged days are left out. A partially logged day may make the average lower.")
                        .nibbleFont(size: 10).foregroundStyle(Color.muted)
                }.cardSurface()
                MacroWeekView(week: MacroWeek(entries: appState.entries, ending: Date()))
                dayDetail
            }.foregroundStyle(Color.ink).padding(23).padding(.top, 8)
        }
    }

    private var dayDetail: some View {
        let entries = appState.entries(on: selectedDay)
        let totals = DailyTotals(entries: entries)
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: selectedDay.diaryTitle, detail: entries.isEmpty ? "nothing logged" : "\(totals.calories.whole) calories")
            if entries.isEmpty {
                Text("An open page. You can add an earlier meal from the diary’s date picker.")
                    .nibbleFont(size: 14).foregroundStyle(Color.muted).cardSurface()
            } else {
                ForEach(entries) { entry in
                    NibbleAdaptiveStack(spacing: 12) {
                        FoodBadge(food: entry.food, size: 42)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.food.name).nibbleFont(size: 13, weight: .semibold)
                            Text("\(entry.meal.title) · \(entry.portionDescription)").nibbleFont(size: 11).foregroundStyle(Color.muted)
                        }
                        Text(entry.calories.whole).nibbleFont(size: 15, weight: .semibold, design: .rounded)
                    }.cardSurface(padding: 13)
                }
            }
        }
    }
}
