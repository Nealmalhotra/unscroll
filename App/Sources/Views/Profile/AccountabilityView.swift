import SwiftUI
import UnscrollKit

struct AccountabilityView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var phone = ""
    @State private var notify = true
    @State private var pledgeAmount = 5
    @State private var causeName = ""
    @State private var causeURL = ""

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Phone", text: $phone).keyboardType(.phonePad)
                Toggle("Ask me to text them when I miss my goal", isOn: $notify)
                Button(model.state.partner == nil ? "Add partner" : "Save partner") {
                    Task { await model.savePartner(AccountabilityPartner(name: name, phone: phone, notifyOnMissedGoal: notify)) }
                }
                if model.state.partner != nil {
                    Button("Remove partner", role: .destructive) { Task { await model.savePartner(nil) } }
                }
            } header: {
                Text("Accountability partner")
            } footer: {
                Text("A friend, partner or parent who hears about it when you slip. Unscroll drafts the message; you hit send. Nothing is sent without you.")
            }
            Section {
                Stepper("$\(pledgeAmount) per missed day", value: $pledgeAmount, in: 1...100)
                TextField("Cause (e.g. local library)", text: $causeName)
                TextField("Donation link (optional)", text: $causeURL).keyboardType(.URL).textInputAutocapitalization(.never)
                Button(model.state.pledge == nil ? "Make pledge" : "Update pledge") {
                    let url = URL(string: causeURL).flatMap { $0.scheme == "https" ? $0 : nil }
                    Task { await model.savePledge(Pledge(amountDollars: pledgeAmount, causeName: causeName, causeURL: url, owed: model.state.pledge?.owed ?? 0)) }
                }
                .disabled(causeName.trimmingCharacters(in: .whitespaces).isEmpty)
                if model.state.pledge != nil {
                    Button("Cancel pledge", role: .destructive) { Task { await model.savePledge(nil) } }
                }
            } header: {
                Text("Put money on it")
            } footer: {
                Text("An honor-system stake: miss your daily goal and you donate to a cause you chose. No payment details are ever collected.")
            }
        }
        .navigationTitle("Accountability")
        .onAppear(perform: load)
    }

    private func load() {
        if let partner = model.state.partner {
            name = partner.name
            phone = partner.phone
            notify = partner.notifyOnMissedGoal
        }
        if let pledge = model.state.pledge {
            pledgeAmount = pledge.amountDollars
            causeName = pledge.causeName
            causeURL = pledge.causeURL?.absoluteString ?? ""
        }
    }
}
