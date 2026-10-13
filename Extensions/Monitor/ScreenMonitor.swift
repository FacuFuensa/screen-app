import DeviceActivity
import Foundation

final class ScreenMonitor: DeviceActivityMonitor {
    private let enforcer = Enforcer()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let a = ActivityName.parse(activity) else { return }
        switch a.kind {
        case "daily": enforcer.refreshAll()  // midnight: the ledger rolls inside refreshAll
        case "window": enforcer.updateRuntime(a.groupID) { $0.inWindow = true }
        default: break
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let a = ActivityName.parse(activity) else { return }
        switch a.kind {
        case "window":
            // The 23:59 end of an overnight window is not the end of the block.
            let segments = enforcer.group(a.groupID)?.window?.segments() ?? []
            if let i = a.index, segments.indices.contains(i), segments[i].continuesNextDay { return }
            enforcer.updateRuntime(a.groupID) { $0.inWindow = false }
        case "extra":
            enforcer.endCredit(groupID: a.groupID)
        default: break
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard let a = ActivityName.parse(activity) else { return }
        switch (a.kind, event) {
        case ("daily", .limit):
            enforcer.updateRuntime(a.groupID) { $0.limitReached = true }
            Outbox().enqueue(kind: "limit_reached", groupID: a.groupID)
        case ("daily", .warn):
            Outbox().enqueue(kind: "threshold_80", groupID: a.groupID)
        case ("extra", .used):
            enforcer.endCredit(groupID: a.groupID)
        default: break
        }
    }
}
