import SwiftUI
import UnscrollKit
import WidgetKit

struct StreakEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), summary: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
    }

    /// The app reloads timelines whenever it saves; this also refreshes just after midnight
    /// (yesterday joins the streak) and every 30 minutes for the goal ring.
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 3600 + 60)
        let next = min(midnight, now.addingTimeInterval(30 * 60))
        completion(Timeline(entries: [entry(at: now)], policy: .after(next)))
    }

    private func entry(at date: Date) -> StreakEntry {
        // The app is the only writer of state.json and replaces it atomically, so reading is safe.
        let file = JSONFile<AppState>(url: SharedContainer.directory().appendingPathComponent("state.json"))
        let state = (try? file.load()) ?? AppState()
        return StreakEntry(date: date, summary: state.widgetSummary(now: date))
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StreakWidget", provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Your Unscroll streak and today's goal.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct UnscrollWidgets: WidgetBundle {
    var body: some Widget { StreakWidget() }
}
