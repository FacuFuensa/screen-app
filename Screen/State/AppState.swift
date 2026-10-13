import FamilyControls
import Foundation

@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable { case loading, signedOut, needsScreenTime, unpaired, ready }

    @Published var phase: Phase = .loading
    @Published var me: ProfileRow?
    @Published var partner: ProfileRow?
    @Published var pair: PairRow?

    let backend = Backend.shared

    var isPaired: Bool { pair?.userB != nil }

    func refresh() async {
        guard let myID = await backend.currentUserID() else { phase = .signedOut; return }
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { phase = .needsScreenTime; return }
        do {
            let pair = try await backend.myPair()
            let profiles = try await backend.profiles()
            self.pair = pair
            me = profiles.first { $0.id == myID }
            partner = profiles.first { $0.id != myID }
            phase = pair?.userB != nil ? .ready : .unpaired
        } catch {
            // Offline: keep whatever we showed last; limits still work locally.
            if phase == .loading { phase = .unpaired }
        }
    }
}
