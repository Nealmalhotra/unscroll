import SwiftUI
import UnscrollKit
import UnscrollScreenTime

struct IntentionEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Intention
    @State private var limitTime: Bool
    @State private var limitOpens: Bool
    private let isNew: Bool

    init(intention: Intention) {
        _draft = State(initialValue: intention)
        _limitTime = State(initialValue: intention.dailyMinutes != nil || intention.name.isEmpty)
        _limitOpens = State(initialValue: intention.dailyOpens != nil)
        isNew = intention.name.isEmpty
    }

    private var result: Intention {
        var copy = draft
        copy.dailyMinutes = limitTime ? (draft.dailyMinutes ?? 30) : nil
        copy.dailyOpens = limitOpens ? (draft.dailyOpens ?? 3) : nil
        return copy
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Social media)", text: $draft.name)
                    SelectionPickerRow(title: "Apps & categories", selectionData: $draft.selectionData)
                }
                Section {
                    Toggle("Daily time limit", isOn: $limitTime)
                    if limitTime {
                        Stepper("\(TimeFormat.minutes(draft.dailyMinutes ?? 30)) a day", value: Binding(
                            get: { draft.dailyMinutes ?? 30 }, set: { draft.dailyMinutes = $0 }
                        ), in: 5...720, step: 5)
                    }
                    Toggle("Limit opens", isOn: $limitOpens)
                    if limitOpens {
                        Stepper("\(draft.dailyOpens ?? 3) opens a day", value: Binding(
                            get: { draft.dailyOpens ?? 3 }, set: { draft.dailyOpens = $0 }
                        ), in: 1...50)
                        Stepper("\(draft.minutesPerOpen) min per open", value: $draft.minutesPerOpen, in: 1...60)
                    }
                } footer: {
                    Text("Apps with an opens limit stay behind a shield that asks \"Is this intentional?\" each time. Going over a limit never locks you out, but you lose today's credit for the intention.")
                }
                if !result.validationErrors.isEmpty || SelectionCodec.isEmpty(draft.selectionData) {
                    Section {
                        ForEach(result.validationErrors, id: \.self) { Text($0).foregroundStyle(Theme.danger) }
                        if SelectionCodec.isEmpty(draft.selectionData) { Text("Choose at least one app or category.").foregroundStyle(Theme.danger) }
                    }
                }
                if !isNew {
                    Section {
                        Button("Delete intention", role: .destructive) { Task { await model.deleteIntention(draft.id); dismiss() } }
                    }
                }
            }
            .navigationTitle(isNew ? "New intention" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await model.saveIntention(result); dismiss() } }
                        .disabled(!result.isValid || SelectionCodec.isEmpty(draft.selectionData))
                }
            }
        }
    }
}
