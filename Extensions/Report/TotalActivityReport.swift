import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

struct AppUsage: Identifiable {
    let id: String
    let token: ApplicationToken?
    let name: String
    let duration: TimeInterval
    let pickups: Int
}

struct ActivitySummary {
    var total: TimeInterval = 0
    var pickups = 0
    var apps: [AppUsage] = []
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (ActivitySummary) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivitySummary {
        var total: TimeInterval = 0
        var pickups = 0
        var byApp: [String: AppUsage] = [:]
        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                total += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        let name = app.application.localizedDisplayName ?? app.application.bundleIdentifier ?? "App"
                        let key = app.application.bundleIdentifier ?? name
                        let previous = byApp[key]
                        byApp[key] = AppUsage(
                            id: key, token: app.application.token, name: name,
                            duration: (previous?.duration ?? 0) + app.totalActivityDuration,
                            pickups: (previous?.pickups ?? 0) + app.numberOfPickups
                        )
                        pickups += app.numberOfPickups
                    }
                }
            }
        }
        let apps = byApp.values.sorted { $0.duration > $1.duration }
        return ActivitySummary(total: total, pickups: pickups, apps: Array(apps.prefix(15)))
    }
}

struct TotalActivityView: View {
    let summary: ActivitySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading) {
                    Text("Screen time").font(.caption).foregroundStyle(.secondary)
                    Text(Self.format(summary.total)).font(.system(size: 40, weight: .bold, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Pickups").font(.caption).foregroundStyle(.secondary)
                    Text("\(summary.pickups)").font(.title.bold())
                }
            }
            Divider()
            ForEach(summary.apps) { app in
                HStack(spacing: 12) {
                    if let token = app.token {
                        Label(token).labelStyle(.iconOnly).frame(width: 32, height: 32)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name).font(.subheadline.weight(.semibold))
                        GeometryReader { proxy in
                            Capsule().fill(Color.green.gradient)
                                .frame(width: max(4, proxy.size.width * app.duration / max(1, summary.apps.first?.duration ?? 1)))
                        }
                        .frame(height: 6)
                    }
                    Text(Self.format(app.duration)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            if summary.apps.isEmpty {
                Text("No activity recorded yet.").foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    static func format(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
