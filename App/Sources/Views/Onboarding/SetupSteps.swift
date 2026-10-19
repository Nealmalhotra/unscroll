import FamilyControls
import SwiftUI
import UnscrollKit
import UnscrollScreenTime

struct PermissionStep: View {
    @Environment(AppModel.self) private var model
    @State private var error: String?
    @State private var isRequesting = false
    let next: () -> Void

    var body: some View {
        OnboardingPage(buttonTitle: model.screenTime.isAuthorized ? "Continue" : "Allow Screen Time access", buttonDisabled: isRequesting, action: request) {
            Image(systemName: "hourglass.circle.fill").font(.system(size: 72)).foregroundStyle(Theme.accent)
            Text("Connect Screen Time").font(.title.bold())
            Text("Unscroll uses Apple's Screen Time API to block apps and track usage. Apple keeps your data private: Unscroll never sees which apps you use or what you do in them, and nothing leaves your phone unless you join a leaderboard server.")
                .foregroundStyle(.secondary)
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.danger).font(.callout)
            }
        }
    }

    private func request() {
        guard !model.screenTime.isAuthorized else { return next() }
        isRequesting = true
        Task {
            defer { isRequesting = false }
            do {
                try await model.screenTime.requestAuthorization()
                if model.screenTime.isAuthorized { next() }
            } catch {
                #if targetEnvironment(simulator)
                // The Simulator can't grant Family Controls; let the rest of the flow be explored.
                return next()
                #else
                self.error = "Screen Time access is required. You can enable it in Settings › Screen Time. (\(error.localizedDescription))"
                #endif
            }
        }
    }
}

/// Requires "All Apps & Categories" so the daily goal and usage milestones cover everything.
struct TrackingStep: View {
    @Environment(AppModel.self) private var model
    @State private var isPresented = false
    @State private var selection = FamilyActivitySelection()
    @State private var error: String?
    let next: () -> Void

    var body: some View {
        OnboardingPage(buttonTitle: hasSelection ? "Continue" : "Choose apps", action: proceed) {
            Text("Track all your apps").font(.title.bold())
            Text("In the next screen, tap **All Apps & Categories** at the top so your daily goal counts everything.")
                .foregroundStyle(.secondary)
            if hasSelection {
                Label("\(selection.categoryTokens.count) categories selected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent).font(.headline)
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.danger).font(.callout)
            }
        }
        .familyActivityPicker(isPresented: $isPresented, selection: $selection)
        .onChange(of: selection) { _, _ in validate() }
    }

    private var hasSelection: Bool { !selection.categoryTokens.isEmpty }

    private func validate() {
        // Apple doesn't expose whether "All" was tapped; a full category set is the closest signal.
        error = selection.categoryTokens.count < 5 && !selection.categoryTokens.isEmpty
            ? "Select All Apps & Categories for accurate tracking."
            : nil
    }

    private func proceed() {
        guard hasSelection, error == nil else {
            isPresented = true
            return
        }
        Task {
            await model.setTrackingSelection(SelectionCodec.encode(selection))
            next()
        }
    }
}

struct GoalStep: View {
    @Binding var goalMinutes: Int
    let reportedHours: Double
    let next: () -> Void

    var body: some View {
        OnboardingPage(action: next) {
            Text("Set your daily goal").font(.title.bold())
            Text("We suggest half your current usage. Stay under it to keep your streak alive.")
                .foregroundStyle(.secondary)
            Text(TimeFormat.minutes(goalMinutes))
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
            Slider(value: Binding(get: { Double(goalMinutes) }, set: { goalMinutes = Int($0) }), in: 30...480, step: 15)
            Text("You told us about \(TimeFormat.minutes(Int(reportedHours * 60))) a day today.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct HandleStep: View {
    @Binding var handle: String
    let finish: () -> Void

    private var isValid: Bool { handle.range(of: "^[A-Za-z0-9_]{3,20}$", options: .regularExpression) != nil }

    var body: some View {
        OnboardingPage(buttonTitle: "Start being present", buttonDisabled: !isValid, action: finish) {
            Text("Pick a username").font(.title.bold())
            Text("Shown on leaderboards. 3–20 letters, numbers or underscores.").foregroundStyle(.secondary)
            TextField("username", text: $handle)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.title2)
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
