import SwiftUI
import UnscrollKit

struct StartSessionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lastSessionSelection") private var selectionData = Data()
    @State private var name = "Focus"
    @State private var minutes = 30
    @State private var mode: BlockMode = .blockSelected
    @State private var beastMode = false
    @State private var groupID: String?

    private let presets = [15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Session name", text: $name)
                    Picker("Length", selection: $minutes) {
                        ForEach(presets, id: \.self) { Text(TimeFormat.minutes($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Stepper("Custom: \(TimeFormat.minutes(minutes))", value: $minutes, in: SessionRules.minimumMinutes...SessionRules.maximumMinutes, step: 5)
                }
                Section("What to block") {
                    Picker("Mode", selection: $mode) {
                        ForEach(BlockMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    SelectionPickerRow(title: mode == .blockSelected ? "Apps to block" : "Apps to allow", selectionData: $selectionData)
                }
                Section {
                    Toggle(isOn: $beastMode) {
                        Label("Beast Mode", systemImage: "flame.fill").foregroundStyle(beastMode ? Theme.beast : .primary)
                    }
                } footer: {
                    Text("No way out until the timer ends, not even from the shield. Earns 1.5× XP.")
                }
                if !model.social.groups.isEmpty {
                    Section("Group session") {
                        Picker("Share with", selection: $groupID) {
                            Text("Just me").tag(String?.none)
                            ForEach(model.social.groups) { Text($0.name).tag(Optional($0.id)) }
                        }
                    }
                }
                Section {
                    Text("You'll earn \(XPRules.sessionXP(minutes: minutes, beastMode: beastMode, outcome: .completed)) XP").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        Task {
                            await model.startSession(name: name, minutes: minutes, mode: mode, beastMode: beastMode, selection: selectionData, groupID: groupID)
                            dismiss()
                        }
                    }
                    .disabled(mode == .blockSelected && selectionData.isEmpty)
                }
            }
        }
    }
}
