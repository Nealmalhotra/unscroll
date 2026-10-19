import FamilyControls
import SwiftUI
import UnscrollKit
import UnscrollScreenTime

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var profile = Profile()
    @State private var tracking = Data()

    var body: some View {
        Form {
            Section {
                Stepper("Daily goal: \(TimeFormat.minutes(profile.dailyGoalMinutes))", value: $profile.dailyGoalMinutes, in: 15...720, step: 15)
                Toggle("Doomscroll alerts (hourly)", isOn: $profile.doomscrollAlertsEnabled)
            } footer: {
                Text("A new goal applies right away, including to today.")
            }
            Section {
                SelectionPickerRow(title: "Tracked apps", selectionData: $tracking)
            } footer: {
                Text("Choose All Apps & Categories so the daily goal counts everything.")
            }
            Section {
                LabeledContent("Screen Time access", value: model.screenTime.isAuthorized ? "Allowed" : "Not allowed")
                if !model.screenTime.isAuthorized {
                    Button("Allow access") { Task { try? await model.screenTime.requestAuthorization() } }
                }
            }
            Section {
                Button("Save") {
                    Task {
                        await model.updateProfile(profile)
                        if tracking != model.trackingSelection { await model.setTrackingSelection(tracking) }
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            profile = model.state.profile
            tracking = model.trackingSelection
        }
    }
}

struct ServerSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var url = ""
    @State private var handle = ""
    @State private var isWorking = false

    var body: some View {
        Form {
            if model.social.isConnected {
                Section {
                    LabeledContent("Server", value: model.social.serverURL?.host() ?? "")
                    LabeledContent("Handle", value: model.social.handle ?? "")
                    Button("Disconnect", role: .destructive) { model.social.disconnect() }
                }
            } else {
                Section {
                    TextField("https://unscroll.example.com", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Handle", text: $handle).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button(isWorking ? "Connecting…" : "Connect") {
                        isWorking = true
                        Task {
                            _ = await model.social.connect(urlString: url, handle: handle)
                            isWorking = false
                            await model.refresh()
                        }
                    }
                    .disabled(isWorking)
                } footer: {
                    Text("Leaderboards and groups run on a tiny server you or a friend can host (see /Server in the repo). Only your handle, weekly XP and estimated screen minutes are shared.")
                }
            }
            if let error = model.social.lastError {
                Section { Text(error).foregroundStyle(Theme.danger) }
            }
        }
        .navigationTitle("Social server")
        .onAppear { handle = model.state.profile.handle }
    }
}
