import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showEdit = false
    @State private var showMacroEditor = false
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Room to be you")
                        Text("Your kind\nof balance.").nibbleFont(size: 35, weight: .semibold, design: .rounded).tracking(-1.5)
                    }
                    Spacer()
                    NibbleMascot(color: .lime, cheerful: true).frame(width: 93, height: 93).rotationEffect(.degrees(8))
                }
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Eyebrow(text: "Your daily target", color: .ink)
                        Spacer()
                        Text(appState.archive.calorieTarget != nil ? "SET BY YOU" : appState.targets != nil ? "ESTIMATED" : "JUST TRACKING")
                            .nibbleFont(size: 8, weight: .bold, design: .monospaced).tracking(1)
                    }
                    if let targets = appState.targets {
                        NibbleAdaptiveStack(spacing: 7) {
                            Text(targets.calories.whole).nibbleFont(size: 49, weight: .semibold, design: .rounded).tracking(-2)
                                .accessibilityIdentifier("plan.calories")
                            Text("cal / day").nibbleFont(size: 14)
                        }
                        NibbleAdaptiveStack(spacing: 12) {
                            planMacro("Protein", value: targets.protein)
                            planMacro("Carbs", value: targets.carbs)
                            planMacro("Fat", value: targets.fat)
                        }
                    } else {
                        Text("Curiosity counts.").nibbleFont(size: 27, weight: .semibold, design: .rounded)
                        Text("Track what you eat without aiming for a number. Add a target whenever it helps.")
                            .nibbleFont(size: 14).foregroundStyle(Color.ink.opacity(0.7))
                    }
                    NibbleButton(title: "Tune my plan", icon: "slider.horizontal.3") { showEdit = true }
                    Button { showMacroEditor = true } label: {
                        Label("Tune macro mix · \(appState.macroSplit.protein)/\(appState.macroSplit.carbs)/\(appState.macroSplit.fat)", systemImage: "circle.hexagongrid")
                            .nibbleFont(size: 13, weight: .semibold).frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityIdentifier("macro.edit")
                }.cardSurface(.lime)
                if let profile = appState.profile {
                    VStack(alignment: .leading, spacing: 17) {
                        SectionHeading(title: "Your starting point")
                        NibbleAdaptiveStack(spacing: 12) {
                            profileStat("Weight", value: appState.archive.units == .metric ? "\(profile.weightKilograms.compact) kg" : "\(profile.weightPounds.compact) lb")
                            profileStat("Height", value: appState.archive.units == .metric ? "\(profile.heightCentimeters.whole) cm" : "\(profile.heightFeet)′ \(profile.heightInchesRemainder)″")
                            profileStat("Age", value: "\(profile.age)")
                        }
                        Divider()
                        Label(profile.goal.title, systemImage: profile.goal.icon).nibbleFont(size: 13, weight: .medium)
                        Text(profile.activity.title).nibbleFont(size: 12).foregroundStyle(Color.muted)
                    }.cardSurface()
                }
                VStack(alignment: .leading, spacing: 17) {
                    SectionHeading(title: "A little transparency")
                    Label("Your diary is saved on this device.", systemImage: "lock")
                        .nibbleFont(size: 13, weight: .medium)
                    Text("No sign-up and no analytics. Barcode numbers are sent to Open Food Facts when you look up a product; your diary and body details are not sent.")
                        .nibbleFont(size: 12).foregroundStyle(Color.muted).lineSpacing(3)
                    Text("Your diary is excluded from device backups. Deleting Nibble or losing this device can lose your diary.")
                        .nibbleFont(size: 12).foregroundStyle(Color.muted).lineSpacing(3)
                    Link("Privacy policy ↗", destination: URL(string: "https://github.com/bond-is-here/nibble/blob/main/PRIVACY.md")!)
                        .nibbleFont(size: 13, weight: .medium)
                    Link("Help & support ↗", destination: URL(string: "https://github.com/bond-is-here/nibble/blob/main/SUPPORT.md")!)
                        .nibbleFont(size: 13, weight: .medium)
                    DisclosureGroup("About targets & food data") {
                        VStack(alignment: .leading, spacing: 13) {
                            Text("Estimated targets use Mifflin–St Jeor resting energy × your activity level. Losing slowly subtracts up to 300 calories (at most 15%); gaining adds 250. Automated estimates have a 1,500-calorie floor. This is a product guardrail, not a personal medical minimum.")
                            Text("Macro targets start at 25% protein, 45% carbs, and 30% fat; customize the split in Tune macro mix. Your current mix is \(appState.macroSplit.protein)/\(appState.macroSplit.carbs)/\(appState.macroSplit.fat). Calorie-only entries don’t contribute known macros. Estimates aren’t a prescription or a weight-loss guarantee.")
                            Link("Read the original Mifflin–St Jeor study ↗", destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/2305711/")!)
                            Link("NIDDK: About adult calorie planning ↗", destination: URL(string: "https://www.niddk.nih.gov/health-information/weight-management/body-weight-planner")!)
                            Text("Generic starter foods are estimates. Product data is contributed by the Open Food Facts community; verify the package and portion. Offline, your saved foods and diary still work.")
                            Link("Open Food Facts · ODbL database license ↗", destination: URL(string: "https://world.openfoodfacts.org/terms-of-use")!)
                        }.nibbleFont(size: 11).foregroundStyle(Color.muted).padding(.top, 12)
                    }.nibbleFont(size: 13, weight: .medium)
                }.cardSurface()
                HStack {
                    Text("nibble.").nibbleFont(size: 22, weight: .black, design: .rounded).tracking(-1)
                    Spacer()
                    Text("Little bites. Real life.").nibbleFont(size: 11).foregroundStyle(Color.muted)
                }.padding(.vertical, 10)
            }.foregroundStyle(Color.ink).padding(23).padding(.top, 8)
        }
        .sheet(isPresented: $showEdit) { OnboardingView(isEditing: true).phoneSheet() }
        .sheet(isPresented: $showMacroEditor) { MacroSplitEditor().phoneSheet() }
    }

    private func planMacro(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(value.whole) g").nibbleFont(size: 17, weight: .semibold, design: .rounded)
            Text(title).nibbleFont(size: 11).foregroundStyle(Color.ink.opacity(0.65))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func profileStat(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).nibbleFont(size: 17, weight: .semibold, design: .rounded)
            Text(title).nibbleFont(size: 11).foregroundStyle(Color.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
