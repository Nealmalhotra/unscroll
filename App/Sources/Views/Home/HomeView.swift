import SwiftUI
import UnscrollKit

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showStart = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HomeHeader()
                    AlertsBanner()
                    if let session = model.state.activeSession {
                        ActiveSessionCard(session: session)
                    } else {
                        StartSessionCard { showStart = true }
                    }
                    QuestsCard()
                    IntentionsCard()
                    ScheduledSessionsCard()
                    TipCard()
                }
                .padding(Theme.padding)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .refreshable { await model.refresh() }
            .sheet(isPresented: $showStart) { StartSessionSheet() }
        }
    }
}

struct HomeHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let xp = model.state.lifetimeXP
        HStack(spacing: 12) {
            StatPill(symbol: "flame.fill", value: "\(model.streak.current)", label: "day streak", color: Theme.warm)
            StatPill(symbol: "bolt.fill", value: "\(model.state.weeklyXP(model.currentWeek))", label: "XP this week")
            VStack(spacing: 6) {
                ZStack {
                    RingProgress(fraction: Level.progress(forXP: xp), lineWidth: 6)
                    Text("\(Level.level(forXP: xp))").font(.headline.bold())
                }
                .frame(width: 40, height: 40)
                Text("level").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

struct StartSessionCard: View {
    let start: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ready to be present?").font(.title2.bold()).foregroundStyle(.white)
            Text("Block distractions and earn 1 XP per minute, or 1.5× in Beast Mode.")
                .foregroundStyle(.white.opacity(0.85))
            Button(action: start) {
                Label("Start a session", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(20)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }
}

struct ActiveSessionCard: View {
    @Environment(AppModel.self) private var model
    let session: ActiveSession
    @State private var confirmEnd = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = session.remaining(at: context.date)
            VStack(spacing: 16) {
                HStack {
                    Label(session.beastMode ? "Beast Mode" : "In session", systemImage: session.beastMode ? "flame.fill" : "leaf.fill")
                        .font(.headline)
                    Spacer()
                    Text(session.name).font(.subheadline).opacity(0.85)
                }
                ZStack {
                    RingProgress(fraction: session.progress(at: context.date), lineWidth: 14, color: .white)
                    VStack(spacing: 4) {
                        Text(Self.format(remaining)).font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                        Text("remaining").font(.caption).opacity(0.8)
                    }
                }
                .frame(width: 200, height: 200)
                if remaining <= 0 {
                    Button("Collect \(XPRules.sessionXP(minutes: session.plannedMinutes, beastMode: session.beastMode, outcome: .completed)) XP") {
                        Task { await model.refresh() }
                    }
                    .buttonStyle(.borderedProminent).tint(.white).foregroundStyle(Theme.accent)
                } else if session.beastMode {
                    Text("Locked until \(session.endsAt.formatted(date: .omitted, time: .shortened)). No exceptions.")
                        .font(.footnote).opacity(0.85)
                } else {
                    Button("End early") { confirmEnd = true }
                        .buttonStyle(.bordered).tint(.white)
                }
            }
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(session.beastMode ? AnyShapeStyle(Theme.beast.gradient) : AnyShapeStyle(Theme.heroGradient), in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        }
        .confirmationDialog("End this session?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End session and lose XP", role: .destructive) { Task { await model.endSessionEarly() } }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Ending early means no XP and no quest credit for this session.")
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%02d:%02d", minutes, seconds)
    }
}

struct AlertsBanner: View {
    @Environment(AppModel.self) private var model
    @State private var showComposer = false

    var body: some View {
        VStack(spacing: 12) {
            if let result = model.state.league.lastResult, result.from != result.to {
                Card {
                    Label(result.to > result.from ? "Promoted to \(result.to.title)! 🎉" : "Moved down to \(result.to.title)",
                          systemImage: result.to.symbol).font(.headline)
                    Text("You finished #\(result.rank) in last week's league.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if let partner = model.state.partner, !model.state.pendingPartnerAlerts.isEmpty {
                Card {
                    Label("Let \(partner.name) know", systemImage: "person.2.fill").font(.headline)
                    Text("You missed your goal \(model.state.pendingPartnerAlerts.count == 1 ? "yesterday" : "on \(model.state.pendingPartnerAlerts.count) days"). Honesty keeps you accountable.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        Button("Text \(partner.name)") { showComposer = true }.buttonStyle(.borderedProminent)
                        Button("Dismiss") { Task { await model.clearPartnerAlerts() } }.buttonStyle(.bordered)
                    }
                }
                .sheet(isPresented: $showComposer) {
                    MessageComposer(recipient: partner.phone, body: partnerMessage) {
                        Task { await model.clearPartnerAlerts() }
                    }
                }
            }
            if let pledge = model.state.pledge, pledge.owed > 0 {
                Card {
                    Label("You owe $\(pledge.owed) to \(pledge.causeName)", systemImage: "heart.circle.fill").font(.headline)
                    HStack {
                        if let url = pledge.causeURL { Link("Donate", destination: url).buttonStyle(.borderedProminent) }
                        Button("I've paid") { Task { await model.settlePledge() } }.buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var partnerMessage: String {
        "Hey, I'm using Unscroll to cut my screen time and I missed my daily goal of \(TimeFormat.minutes(model.state.profile.dailyGoalMinutes)). Keep me honest! 🙏"
    }
}
