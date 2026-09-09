import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showEdit = false
    @State private var showMacroEditor = false
    @State private var showExporter = false
    @State private var exportDocument: NibbleDiaryDocument?
    @State private var exportError: String?
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
                            .nibbleFont(size: 14).foregroundStyle(Color.ink)
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
                    Button(action: prepareExport) {
                        Label("Export a diary copy", systemImage: "square.and.arrow.up")
                            .nibbleFont(size: 13, weight: .semibold)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("diary.export")
                    Text("Save or share a readable JSON copy using the system Files sheet. Nibble does not send it anywhere unless you choose a destination.")
                        .nibbleFont(size: 11).foregroundStyle(Color.muted).lineSpacing(3)
                    if let exportError {
                        InlineMessage(text: exportError)
                    }
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
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json,
                      defaultFilename: "Nibble-diary-export") { result in
            if case .failure = result {
                exportError = "Your diary copy couldn’t be exported. Try again or choose another destination."
            }
            exportDocument = nil
        }
    }

    private func prepareExport() {
        exportError = nil
        do {
            exportDocument = NibbleDiaryDocument(data: try appState.exportData())
            showExporter = true
        } catch {
            exportError = "Your diary copy couldn’t be prepared. Try again."
        }
    }

    private func planMacro(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(value.whole) g").nibbleFont(size: 17, weight: .semibold, design: .rounded)
            Text(title).nibbleFont(size: 11).foregroundStyle(Color.ink)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func profileStat(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).nibbleFont(size: 17, weight: .semibold, design: .rounded)
            Text(title).nibbleFont(size: 11).foregroundStyle(Color.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NibbleDiaryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
