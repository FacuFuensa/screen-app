import ScreenCore
import SwiftUI

/// Drives the first-run tour. Steps only advance through `complete(_:)`, called by
/// the real action (tapping the lit button, picking apps…), never by a "Next" button.
@MainActor
final class TourController: ObservableObject {
    static let shared = TourController()

    @Published private(set) var current: TourStep?
    @Published var showFinal = false

    private let defaults = UserDefaults.standard
    private var done: Bool {
        get { defaults.bool(forKey: "tourDone") }
        set { defaults.set(newValue, forKey: "tourDone") }
    }

    func start(authorized: Bool, groupCount: Int, paired: Bool) {
        guard !done, current == nil, !showFinal else { return }
        current = TourPlan.firstPending(authorized: authorized, groupCount: groupCount, paired: paired)
        if current == nil { done = true }
    }

    func complete(_ step: TourStep) {
        guard current == step else { return }
        withAnimation(.easeInOut(duration: 0.25)) { current = TourPlan.next(after: step) }
        if current == nil { finish() }
    }

    /// Pairing ends the tour wherever it is (the other person may have used my code).
    func pairingCompleted() {
        guard let step = current, step == .invite || step == .share else { return }
        current = nil
        finish()
    }

    func skip() {
        current = nil
        done = true
    }

    func restart() {
        done = false
        showFinal = false
        current = .newLimit
    }

    /// Demo screenshots only.
    func force(_ step: TourStep?, final: Bool = false) {
        current = step
        showFinal = final
    }

    private func finish() {
        done = true
        showFinal = true
    }
}
