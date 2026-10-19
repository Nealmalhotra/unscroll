import DeviceActivity
import UnscrollScreenTime

/// Runs in its own process when schedules start/end or usage thresholds are hit.
final class MonitorExtension: DeviceActivityMonitor {
    private let handler = MonitorHandler()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        handler.intervalDidStart(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        handler.intervalDidEnd(for: activity)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        handler.eventDidReachThreshold(event, activity: activity)
    }
}
