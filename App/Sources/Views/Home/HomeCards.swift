import SwiftUI
import UnscrollKit

struct QuestsCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Card {
            SectionTitle(title: "Daily quests", symbol: "scroll.fill")
            ForEach(model.state.questProgress(on: model.today), id: \.0.id) { quest, progress in
                HStack(spacing: 12) {
                    Image(systemName: progress.isComplete ? "checkmark.circle.fill" : quest.symbol)
                        .font(.title3)
                        .foregroundStyle(progress.isComplete ? Theme.accent : .secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(quest.title).font(.subheadline.weight(.semibold)).strikethrough(progress.isComplete)
                        ProgressView(value: progress.fraction).tint(Theme.accent)
                        if quest.resolvesAtDayEnd && !progress.isComplete {
                            Text("Checked at the end of the day").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Text("+\(quest.xp)").font(.caption.bold()).foregroundStyle(Theme.accent)
                }
            }
        }
    }
}

struct IntentionsCard: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Intention?

    var body: some View {
        Card {
            SectionTitle(title: "Intentions", symbol: "hand.raised.fill", trailing: AnyView(
                Button { editing = Intention(name: "") } label: { Image(systemName: "plus.circle.fill").font(.title3) }
            ))
            if model.state.intentions.isEmpty {
                Text("Set limits on your most distracting apps: a daily time allowance, a number of opens, or both.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(model.state.intentions) { intention in
                Button { editing = intention } label: { IntentionRow(intention: intention, record: model.todayRecord) }
                    .foregroundStyle(.primary)
            }
        }
        .sheet(item: $editing) { IntentionEditor(intention: $0) }
    }
}

struct IntentionRow: View {
    let intention: Intention
    let record: DayRecord

    var body: some View {
        let broken = record.brokenIntentions.contains(intention.id)
        let opens = record.opens[intention.id] ?? 0
        HStack {
            SelectionSummary(data: intention.selectionData).frame(width: 60, alignment: .leading)
            VStack(alignment: .leading) {
                Text(intention.name).font(.subheadline.weight(.semibold))
                Text(intention.summary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let limit = intention.dailyOpens {
                Text("\(opens)/\(limit)").font(.subheadline.monospacedDigit()).foregroundStyle(broken ? Theme.danger : .secondary)
            }
            Image(systemName: broken ? "xmark.circle.fill" : "checkmark.circle")
                .foregroundStyle(broken ? Theme.danger : Theme.accent)
        }
    }
}

struct ScheduledSessionsCard: View {
    @Environment(AppModel.self) private var model
    @State private var editing: SessionPlan?

    var body: some View {
        Card {
            SectionTitle(title: "Scheduled sessions", symbol: "calendar.badge.clock", trailing: AnyView(
                Button { editing = SessionPlan(name: "", startMinute: 21 * 60, endMinute: 22 * 60) } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            ))
            if model.state.plans.isEmpty {
                Text("Block apps automatically every morning, at bedtime or during work.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(model.state.plans.sorted { $0.startMinute < $1.startMinute }) { plan in
                Button { editing = plan } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            HStack(spacing: 4) {
                                Text(plan.name).font(.subheadline.weight(.semibold))
                                if plan.beastMode { Image(systemName: "flame.fill").foregroundStyle(Theme.beast).font(.caption) }
                            }
                            Text("\(plan.timeLabel) · \(WeekdayPicker.label(plan.weekdays))").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: plan.enabled ? "bell.fill" : "bell.slash").foregroundStyle(plan.enabled ? Theme.accent : .secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .sheet(item: $editing) { PlanEditor(plan: $0) }
    }
}

struct TipCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let tip = Tips.tip(for: model.today)
        let read = model.todayRecord.tipRead
        Card {
            SectionTitle(title: "Tip of the day", symbol: "lightbulb.fill")
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: tip.symbol).font(.title2).foregroundStyle(Theme.warm).frame(width: 32)
                VStack(alignment: .leading, spacing: 6) {
                    Text(tip.title).font(.subheadline.bold())
                    if read {
                        Text(tip.body).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            if !read {
                Button("Read tip (+\(XPRules.tipRead) XP)") { Task { await model.readTip() } }
                    .buttonStyle(.bordered)
            }
        }
    }
}
