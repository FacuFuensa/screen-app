import Foundation
import ScreenCore

/// Requests and events between the two people, shared by both tabs so they never
/// disagree, and the single place that answers or cancels (one call per tap).
@MainActor
final class ActivityModel: ObservableObject {
    @Published private(set) var requests: [RequestRow] = []
    @Published private(set) var events: [EventRow] = []
    @Published private(set) var busy: Set<UUID> = []
    @Published var error: String?

    let backend = Backend.shared

    func load() async {
        if Demo.isOn {
            requests = Demo.requests
            events = Demo.events
            return
        }
        do {
            async let loadedRequests = backend.requests()
            async let loadedEvents = backend.events()
            requests = try await loadedRequests
            events = try await loadedEvents
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func incoming(from partnerID: UUID?) -> [RequestRow] {
        guard let partnerID else { return [] }
        return requests.filter { $0.fromUser == partnerID && $0.effectiveStatus() == .pending }
    }

    func ownPendingExtra(me: UUID?) -> RequestRow? {
        requests.first { $0.fromUser == me && $0.kind == .extraTime && $0.effectiveStatus() == .pending }
    }

    func hasOwnPending(me: UUID?) -> Bool {
        requests.contains { $0.fromUser == me && $0.effectiveStatus() == .pending }
    }

    /// Repeated taps while the call is in flight are ignored.
    @discardableResult
    func answer(_ requestID: UUID, grant: Bool, minutes: Int? = nil) async -> Bool {
        guard !busy.contains(requestID) else { return false }
        busy.insert(requestID)
        defer { busy.remove(requestID) }
        if Demo.isOn {
            requests.removeAll { $0.id == requestID }
            return true
        }
        do {
            try await backend.answer(requestID: requestID, grant: grant, minutes: minutes)
            await backend.notify(requestID: requestID)
            await load()
            return true
        } catch {
            self.error = error.localizedDescription
            await load()
            return false
        }
    }

    func cancel(_ requestID: UUID) async {
        guard !busy.contains(requestID) else { return }
        busy.insert(requestID)
        defer { busy.remove(requestID) }
        if Demo.isOn {
            requests.removeAll { $0.id == requestID }
            return
        }
        do {
            try await backend.cancelRequest(requestID)
        } catch {
            self.error = error.localizedDescription
        }
        await load()
    }
}
