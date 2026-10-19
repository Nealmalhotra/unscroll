import SwiftUI
import UnscrollKit

struct PlanEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SessionPlan
    private let isNew: Bool

    init(plan: SessionPlan) {
        _draft = State(initialValue: plan)
        isNew = plan.name.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Bedtime)", text: $draft.name)
                    DatePicker("Starts", selection: minuteBinding(\.startMinute), displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: minuteBinding(\.endMinute), displayedComponents: .hourAndMinute)
                    WeekdayPicker(selection: $draft.weekdays)
                }
                Section("What to block") {
                    Picker("Mode", selection: $draft.mode) {
                        ForEach(BlockMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    SelectionPickerRow(title: draft.mode == .blockSelected ? "Apps to block" : "Apps to allow", selectionData: $draft.selectionData)
                }
                Section {
                    Toggle("Beast Mode", isOn: $draft.beastMode)
                    Toggle("Enabled", isOn: $draft.enabled)
                }
                if !draft.validationErrors.isEmpty {
                    Section { ForEach(draft.validationErrors, id: \.self) { Text($0).foregroundStyle(Theme.danger) } }
                }
                if !isNew {
                    Section {
                        Button("Delete session", role: .destructive) {
                            Task { await model.deletePlan(draft.id); dismiss() }
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New schedule" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await model.savePlan(draft); dismiss() } }.disabled(!draft.isValid)
                }
            }
        }
    }

    private func minuteBinding(_ keyPath: WritableKeyPath<SessionPlan, Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(draft[keyPath: keyPath] * 60)) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                draft[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    static let symbols = Calendar.current.veryShortWeekdaySymbols

    var body: some View {
        HStack {
            ForEach(1...7, id: \.self) { day in
                let isOn = selection.contains(day)
                Button(Self.symbols[day - 1]) {
                    selection = isOn ? selection.subtracting([day]) : selection.union([day])
                }
                .frame(width: 34, height: 34)
                .background(isOn ? Theme.accent : Color.secondary.opacity(0.12), in: Circle())
                .foregroundStyle(isOn ? .white : .primary)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }

    static func label(_ days: Set<Int>) -> String {
        switch days {
        case Set(1...7): "Every day"
        case Set(2...6): "Weekdays"
        case [1, 7]: "Weekends"
        default: days.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
        }
    }
}
