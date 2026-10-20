import SwiftUI
import UnscrollKit
import WidgetKit

enum WidgetTheme {
    static let green = Color(red: 0.16, green: 0.55, blue: 0.43)
    static let deepGreen = Color(red: 0.10, green: 0.36, blue: 0.30)
    static let flame = Color(red: 0.98, green: 0.62, blue: 0.29)
    static let risk = Color(red: 0.89, green: 0.30, blue: 0.31)
}

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    var body: some View {
        switch family {
        case .accessoryCircular: CircularStreak(summary: entry.summary)
        case .accessoryRectangular: RectangularStreak(summary: entry.summary)
        case .accessoryInline: Label("\(entry.summary.streak)-day streak", systemImage: "flame.fill")
        case .systemMedium: MediumStreak(summary: entry.summary)
        default: SmallStreak(summary: entry.summary)
        }
    }
}

private struct HomeBackground: View {
    let onTrack: Bool

    var body: some View {
        LinearGradient(
            colors: onTrack ? [WidgetTheme.deepGreen, WidgetTheme.green] : [Color(red: 0.55, green: 0.18, blue: 0.16), WidgetTheme.risk],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

private struct StatusLine: View {
    let summary: WidgetSummary

    var body: some View {
        Label(summary.todayOnTrack ? "On track today" : "Streak at risk",
              systemImage: summary.todayOnTrack ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

struct SmallStreak: View {
    let summary: WidgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: "flame.fill").font(.title2).foregroundStyle(WidgetTheme.flame)
            Spacer(minLength: 0)
            Text("\(summary.streak)")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            Text("day streak").font(.subheadline.weight(.semibold)).opacity(0.9)
            StatusLine(summary: summary).opacity(0.85).padding(.top, 4)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { HomeBackground(onTrack: summary.todayOnTrack) }
        .widgetURL(URL(string: "unscroll://home"))
    }
}

struct MediumStreak: View {
    let summary: WidgetSummary

    var body: some View {
        HStack(spacing: 16) {
            SmallStreak(summary: summary)
            VStack(spacing: 10) {
                ZStack {
                    Circle().stroke(.white.opacity(0.2), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: summary.goalRemainingFraction)
                        .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int(summary.goalRemainingFraction * 100))%").font(.headline.bold())
                        Text("goal left").font(.system(size: 9)).opacity(0.8)
                    }
                }
                .frame(width: 78, height: 78)
                HStack(spacing: 10) {
                    Label("\(summary.weeklyXP)", systemImage: "bolt.fill")
                    Label("Lv \(summary.level)", systemImage: "star.fill")
                }
                .font(.caption2.weight(.semibold))
                .labelStyle(.titleAndIcon)
            }
            .foregroundStyle(.white)
        }
        .containerBackground(for: .widget) { HomeBackground(onTrack: summary.todayOnTrack) }
    }
}

struct CircularStreak: View {
    let summary: WidgetSummary

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Image(systemName: "flame.fill").font(.caption)
                Text("\(summary.streak)").font(.title2.bold()).minimumScaleFactor(0.6)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct RectangularStreak: View {
    let summary: WidgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("\(summary.streak)-day streak", systemImage: "flame.fill").font(.headline)
            Text(summary.todayOnTrack ? "On track today" : "Streak at risk").font(.caption)
            Gauge(value: summary.goalRemainingFraction) { Text("Goal") }
                .gaugeStyle(.accessoryLinearCapacity)
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

#Preview("Small", as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, summary: .placeholder)
}
