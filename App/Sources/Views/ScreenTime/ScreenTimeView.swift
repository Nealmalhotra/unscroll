import Charts
import DeviceActivity
import SwiftUI
import UnscrollKit

extension DeviceActivityReport.Context {
    /// Must match the context in the report extension.
    static let totalActivity = Self("Total Activity")
}

struct ScreenTimeView: View {
    @Environment(AppModel.self) private var model
    @State private var range: Range = .today

    enum Range: String, CaseIterable { case today = "Today", week = "This week" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GoalRingCard(record: model.todayRecord, onTrack: model.streak.todayOnTrack)
                    Picker("Range", selection: $range) {
                        ForEach(Range.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HistoryChart(days: model.state.days, today: model.today)
                    if model.screenTime.isAuthorized {
                        // Rendered by the sandboxed report extension; the app never sees the raw data.
                        DeviceActivityReport(.totalActivity, filter: filter)
                            .frame(minHeight: 420)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.corner))
                    } else {
                        Card {
                            Label("Per-app breakdown", systemImage: "apps.iphone").font(.headline)
                            Text("Allow Screen Time access in Profile › Settings to see time and pickups per app. (Not available in the Simulator.)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(Theme.padding)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Screen Time")
        }
    }

    private var filter: DeviceActivityFilter {
        let calendar = Calendar.current
        let now = Date()
        switch range {
        case .today:
            let interval = calendar.dateInterval(of: .day, for: now) ?? DateInterval(start: now, duration: 86_400)
            return DeviceActivityFilter(segment: .daily(during: interval), users: .all, devices: .init([.iPhone]))
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 7 * 86_400)
            return DeviceActivityFilter(segment: .daily(during: interval), users: .all, devices: .init([.iPhone]))
        }
    }
}

struct GoalRingCard: View {
    let record: DayRecord
    let onTrack: Bool

    var body: some View {
        Card {
            HStack(spacing: 20) {
                ZStack {
                    RingProgress(fraction: record.goalRemainingFraction, lineWidth: 14, color: record.goalExceeded ? Theme.danger : Theme.accent)
                    VStack(spacing: 0) {
                        Text("\(Int(record.goalRemainingFraction * 100))%").font(.title2.bold())
                        Text("left").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 110, height: 110)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Daily goal").font(.headline)
                    Text("At least \(TimeFormat.minutes(record.screenMinutesAtLeast)) of \(TimeFormat.minutes(record.goalMinutes)) used")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Label(onTrack ? "Streak on track" : "Streak at risk", systemImage: onTrack ? "flame.fill" : "exclamationmark.triangle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(onTrack ? Theme.warm : Theme.danger)
                }
            }
            Text("Estimated in 15-minute steps. Exact numbers are in the report below.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct HistoryChart: View {
    let days: [DayKey: DayRecord]
    let today: DayKey

    var body: some View {
        let series = (0..<7).reversed().map { today.adding(days: -$0) }.map { day in
            (day: day, minutes: days[day]?.screenMinutesAtLeast ?? 0, met: days[day]?.isSuccess ?? true, goal: days[day]?.goalMinutes)
        }
        Card {
            SectionTitle(title: "Last 7 days", symbol: "chart.bar.fill")
            Chart {
                ForEach(series, id: \.day) { point in
                    BarMark(x: .value("Day", point.day.startDate(), unit: .day), y: .value("Minutes", point.minutes))
                        .foregroundStyle(point.met ? Theme.accent : Theme.danger)
                        .cornerRadius(6)
                }
                if let goal = series.last?.goal {
                    RuleMark(y: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .annotation(position: .top, alignment: .leading) { Text("Goal").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
            .frame(height: 180)
        }
    }
}
