import SwiftUI
import UnscrollKit

struct LeaderboardView: View {
    @State private var tab: Tab = .league
    enum Tab: String, CaseIterable { case league = "League", groups = "Groups" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Leaderboard", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()
                switch tab {
                case .league: LeagueView()
                case .groups: GroupsView()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Leaderboard")
        }
    }
}

struct LeagueView: View {
    @Environment(AppModel.self) private var model
    @State private var server: ServerLeague?

    var body: some View {
        let tier = server.flatMap { Tier(rawValue: $0.tier) } ?? model.state.league.tier
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: tier.symbol).font(.system(size: 48)).foregroundStyle(Theme.accent)
                    Text("\(tier.title) League").font(.title2.bold())
                    Text("Top \(LeagueEngine.promoteCount) move up. Resets every Monday.").font(.subheadline).foregroundStyle(.secondary)
                    if server == nil {
                        Text("Offline league. Connect a server in Profile to compete with real people.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                ForEach(standings) { standing in
                    StandingRow(standing: standing, zone: LeagueEngine.zone(rank: standing.rank, tier: tier, cohortSize: standings.count))
                }
            }
        }
        .task { server = await model.social.league(week: model.currentWeek) }
        .refreshable {
            await model.refresh()
            server = await model.social.league(week: model.currentWeek)
        }
    }

    private var standings: [Standing] {
        if let server {
            return server.standings.map { Standing(handle: $0.handle, xp: $0.xp, rank: $0.rank, isMe: $0.isMe) }
        }
        return LeagueEngine.simulatedStandings(
            week: model.currentWeek, tier: model.state.league.tier, myHandle: model.state.profile.handle,
            myXP: model.state.weeklyXP(model.currentWeek), progress: model.currentWeek.progress(at: Date())
        )
    }
}

struct StandingRow: View {
    let standing: Standing
    let zone: LeagueZone

    var body: some View {
        HStack {
            Text("\(standing.rank)").font(.headline.monospacedDigit()).frame(width: 32)
                .foregroundStyle(zone == .promote ? Theme.accent : zone == .demote ? Theme.danger : .secondary)
            Text(standing.handle).font(standing.isMe ? .body.bold() : .body)
            if standing.isMe { Text("you").font(.caption.bold()).padding(.horizontal, 6).padding(.vertical, 2).background(Theme.accent.opacity(0.2), in: Capsule()) }
            Spacer()
            Text("\(standing.xp) XP").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
        .listRowBackground(standing.isMe ? Theme.accent.opacity(0.1) : nil)
    }
}
