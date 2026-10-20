import SwiftUI
import UnscrollKit

struct ProfileView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: model.state.league.tier.symbol).font(.largeTitle).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading) {
                            Text("@\(model.state.profile.handle)").font(.title2.bold())
                            Text("Level \(Level.level(forXP: model.state.lifetimeXP)) · \(model.state.league.tier.title) League").foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Stats") {
                    LabeledContent("Lifetime XP", value: "\(model.state.lifetimeXP)")
                    LabeledContent("Current streak", value: "\(model.streak.current) days")
                    LabeledContent("Longest streak", value: "\(model.streak.longest) days")
                    LabeledContent("Sessions completed", value: "\(model.state.sessionHistory.filter { $0.outcome == .completed }.count)")
                    LabeledContent("Minutes in sessions", value: "\(model.state.sessionHistory.filter { $0.outcome == .completed }.reduce(0) { $0 + $1.actualMinutes })")
                }
                Section {
                    NavigationLink { RewardsView() } label: {
                        LabeledContent { Text("\(model.state.pointsBalance) pts") } label: { Label("Rewards", systemImage: "gift.fill") }
                    }
                    NavigationLink { AccountabilityView() } label: { Label("Accountability", systemImage: "person.2.fill") }
                    NavigationLink { LearnView() } label: { Label("Learn", systemImage: "book.fill") }
                }
                Section {
                    NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gearshape.fill") }
                    NavigationLink { ServerSettingsView() } label: {
                        LabeledContent { Text(model.social.isConnected ? "Connected" : "Offline") } label: { Label("Social server", systemImage: "server.rack") }
                    }
                }
                if let repo = URL(string: "https://github.com/Nealmalhotra/unscroll") {
                    Section {
                        Link(destination: repo) {
                            Label("Unscroll is open source (MIT)", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

struct RewardsView: View {
    @Environment(AppModel.self) private var model
    @State private var newTitle = ""
    @State private var newCost = 500
    @State private var celebrate: Reward?

    var body: some View {
        List {
            Section {
                VStack(spacing: 4) {
                    Text("\(model.state.pointsBalance)").font(.system(size: 48, weight: .heavy, design: .rounded))
                    Text("points to spend").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            } footer: {
                Text("Points come from the XP you earn. Spending them doesn't lower your level or league score. Set your own real-life rewards and treat yourself when you've earned it.")
            }
            Section("Your rewards") {
                ForEach(model.state.rewards.sorted { $0.cost < $1.cost }) { reward in
                    HStack {
                        Text(reward.emoji).font(.title2)
                        VStack(alignment: .leading) {
                            Text(reward.title)
                            Text("\(reward.cost) pts").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Redeem") {
                            Task { if await model.redeem(reward) { celebrate = reward } }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.state.pointsBalance < reward.cost)
                    }
                    .swipeActions { Button("Delete", role: .destructive) { Task { await model.deleteReward(reward.id) } } }
                }
            }
            Section("Add a reward") {
                TextField("e.g. Concert tickets", text: $newTitle)
                Stepper("\(newCost) points", value: $newCost, in: 50...100_000, step: 50)
                Button("Add") {
                    Task {
                        await model.saveReward(Reward(title: newTitle, cost: newCost))
                        newTitle = ""
                    }
                }
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if !model.state.redemptions.isEmpty {
                Section("History") {
                    ForEach(model.state.redemptions.reversed()) { redemption in
                        LabeledContent(redemption.title, value: redemption.at.formatted(date: .abbreviated, time: .omitted))
                    }
                }
            }
        }
        .navigationTitle("Rewards")
        .alert("Enjoy it! 🎉", isPresented: Binding(get: { celebrate != nil }, set: { if !$0 { celebrate = nil } })) {
            Button("Thanks") {}
        } message: {
            Text("You earned \"\(celebrate?.title ?? "")\" by being present.")
        }
    }
}

struct LearnView: View {
    var body: some View {
        List(Tips.articles) { article in
            NavigationLink {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(article.topic.uppercased()).font(.caption.bold()).foregroundStyle(Theme.accent)
                        Text(article.title).font(.largeTitle.bold())
                        ForEach(article.paragraphs, id: \.self) { Text($0).font(.body) }
                    }
                    .padding()
                }
            } label: {
                VStack(alignment: .leading) {
                    Text(article.title).font(.headline)
                    Text("\(article.topic) · \(article.minutes) min read").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Learn")
    }
}
