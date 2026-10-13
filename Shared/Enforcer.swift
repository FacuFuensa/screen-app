import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import ScreenCore

enum ActivityName {
    static func daily(_ id: UUID) -> DeviceActivityName { .init("daily.\(id.uuidString)") }
    static func window(_ id: UUID, _ index: Int) -> DeviceActivityName { .init("window.\(id.uuidString).\(index)") }
    static func extra(_ id: UUID) -> DeviceActivityName { .init("extra.\(id.uuidString)") }

    static func parse(_ name: DeviceActivityName) -> (kind: String, groupID: UUID, index: Int?)? {
        let parts = name.rawValue.split(separator: ".").map(String.init)
        guard parts.count >= 2, let id = UUID(uuidString: parts[1]) else { return nil }
        return (parts[0], id, parts.count > 2 ? Int(parts[2]) : nil)
    }
}

extension DeviceActivityEvent.Name {
    static let limit = Self("limit")
    static let warn = Self("warn80")
    static let used = Self("used")
}

/// The only place that touches DeviceActivity and ManagedSettings. Each group
/// owns up to four activities (daily, two window segments, extra time) and one
/// named ManagedSettingsStore; whether it is shielded is GroupRuntime.shouldShield.
final class Enforcer {
    let store: SharedStore
    let center = DeviceActivityCenter()
    var calendar = Calendar.current

    init(store: SharedStore = SharedStore()) { self.store = store }

    var groups: [LimitGroup] { store.load([LimitGroup].self, key: SharedKey.groups) ?? [] }
    func group(_ id: UUID) -> LimitGroup? { groups.first { $0.id == id } }

    func ledger(now: Date) -> DayLedger {
        let today = DayKey.string(for: now, calendar: calendar)
        var l = store.load(DayLedger.self, key: SharedKey.ledger) ?? DayLedger(day: today)
        l.roll(to: today)
        return l
    }

    private func save(_ l: DayLedger) { store.save(l, key: SharedKey.ledger) }

    func updateRuntime(_ id: UUID, now: Date = .now, _ change: (inout GroupRuntime) -> Void) {
        var l = ledger(now: now)
        var rt = l.runtime[id.uuidString, default: GroupRuntime()]
        change(&rt)
        l.runtime[id.uuidString] = rt
        save(l)
        applyShield(id, runtime: rt)
    }

    /// Re-derives every group's shield, e.g. right after midnight.
    func refreshAll(now: Date = .now) {
        var l = ledger(now: now)
        let minute = DayKey.minuteOfDay(now, calendar: calendar)
        for g in groups {
            var rt = l.runtime[g.id.uuidString, default: GroupRuntime()]
            rt.inWindow = g.window?.contains(minute: minute) ?? false
            l.runtime[g.id.uuidString] = rt
        }
        save(l)
        for g in groups { applyShield(g.id, runtime: l.runtime[g.id.uuidString] ?? GroupRuntime()) }
    }

    func applyShield(_ id: UUID, runtime: GroupRuntime) {
        let s = ManagedSettingsStore(named: .init(id.uuidString))
        guard runtime.shouldShield, let g = group(id) else { s.clearAllSettings(); return }
        s.shield.applications = g.selection.applicationTokens.isEmpty ? nil : g.selection.applicationTokens
        s.shield.applicationCategories = g.selection.categoryTokens.isEmpty ? nil : .specific(g.selection.categoryTokens)
        s.shield.webDomains = g.selection.webDomainTokens.isEmpty ? nil : g.selection.webDomainTokens
    }

    /// Stores `new` and restarts monitoring for the groups that changed.
    func install(groups new: [LimitGroup], now: Date = .now) throws {
        let old = groups
        store.save(new, key: SharedKey.groups)
        for g in old where !new.contains(where: { $0.id == g.id }) {
            center.stopMonitoring(activities(for: g.id, includingExtra: true))
            ManagedSettingsStore(named: .init(g.id.uuidString)).clearAllSettings()
        }
        var l = ledger(now: now)
        let minute = DayKey.minuteOfDay(now, calendar: calendar)
        for g in new {
            let before = old.first { $0.id == g.id }
            guard before != g else { continue }
            center.stopMonitoring(activities(for: g.id, includingExtra: false))
            try startDaily(g)
            for (i, seg) in (g.window?.segments() ?? []).enumerated() {
                try center.startMonitoring(ActivityName.window(g.id, i), during: schedule(seg, repeats: true))
            }
            var rt = l.runtime[g.id.uuidString, default: GroupRuntime()]
            // A raised or removed limit clears today's block; a lowered one is
            // re-detected by the threshold event, which counts past usage.
            if let o = before?.dailyMinutes, g.dailyMinutes.map({ $0 > o }) ?? true { rt.limitReached = false }
            rt.inWindow = g.window?.contains(minute: minute) ?? false
            l.runtime[g.id.uuidString] = rt
        }
        save(l)
        for g in new { applyShield(g.id, runtime: l.runtime[g.id.uuidString] ?? GroupRuntime()) }
    }

    /// Unlocks the group for `minutes` of real use. Idempotent per request ID.
    @discardableResult
    func grantCredit(groupID: UUID, minutes: Int, requestID: String?, now: Date = .now) throws -> Bool {
        guard let g = group(groupID) else { return false }
        var l = ledger(now: now)
        if let r = requestID, l.hasApplied(r) { return false }
        let seg = UsageRules.extraTimeInterval(nowMinute: DayKey.minuteOfDay(now, calendar: calendar))
        center.stopMonitoring([ActivityName.extra(groupID)])
        try center.startMonitoring(ActivityName.extra(groupID), during: schedule(seg, repeats: false),
                                   events: [.used: event(g, minutes: minutes, includesPast: false)])
        if let r = requestID { l.markApplied(r) }
        var rt = l.runtime[groupID.uuidString, default: GroupRuntime()]
        rt.creditActive = true
        l.runtime[groupID.uuidString] = rt
        save(l)
        applyShield(groupID, runtime: rt)
        return true
    }

    /// 5 minutes once a day, no approval. The partner hears about it through the outbox.
    func useWildcard(groupID: UUID, now: Date = .now) throws -> Bool {
        guard ledger(now: now).canUseWildcard else { return false }
        guard try grantCredit(groupID: groupID, minutes: UsageRules.wildcardMinutes, requestID: nil, now: now) else { return false }
        var l = ledger(now: now)
        l.consumeWildcard()
        save(l)
        Outbox(store: store).enqueue(kind: "wildcard_used", groupID: groupID, now: now)
        return true
    }

    func endCredit(groupID: UUID, now: Date = .now) {
        center.stopMonitoring([ActivityName.extra(groupID)])
        updateRuntime(groupID, now: now) { $0.creditActive = false }
    }

    func groupID(containing token: ApplicationToken) -> UUID? {
        groups.first { $0.selection.applicationTokens.contains(token) }?.id
    }
    func groupID(containing token: ActivityCategoryToken) -> UUID? {
        groups.first { $0.selection.categoryTokens.contains(token) }?.id
    }
    func groupID(containing token: WebDomainToken) -> UUID? {
        groups.first { $0.selection.webDomainTokens.contains(token) }?.id
    }

    // MARK: - Private

    private func activities(for id: UUID, includingExtra: Bool) -> [DeviceActivityName] {
        var names = [ActivityName.daily(id), ActivityName.window(id, 0), ActivityName.window(id, 1)]
        if includingExtra { names.append(ActivityName.extra(id)) }
        return names
    }

    private func startDaily(_ g: LimitGroup) throws {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        if let daily = g.dailyMinutes {
            events[.limit] = event(g, minutes: daily, includesPast: true)
            if let w = UsageRules.warnThreshold(daily: daily) { events[.warn] = event(g, minutes: w, includesPast: true) }
        }
        // Registered even without a daily limit: its intervalDidStart is the midnight tick.
        try center.startMonitoring(
            ActivityName.daily(g.id),
            during: DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
                                           intervalEnd: DateComponents(hour: 23, minute: 59), repeats: true),
            events: events)
    }

    private func event(_ g: LimitGroup, minutes: Int, includesPast: Bool) -> DeviceActivityEvent {
        DeviceActivityEvent(applications: g.selection.applicationTokens,
                            categories: g.selection.categoryTokens,
                            webDomains: g.selection.webDomainTokens,
                            threshold: DateComponents(minute: minutes),
                            includesPastActivity: includesPast)
    }

    private func schedule(_ seg: DaySegment, repeats: Bool) -> DeviceActivitySchedule {
        DeviceActivitySchedule(intervalStart: DateComponents(hour: seg.startMinute / 60, minute: seg.startMinute % 60),
                               intervalEnd: DateComponents(hour: seg.endMinute / 60, minute: seg.endMinute % 60),
                               repeats: repeats)
    }
}
