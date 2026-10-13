import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: Router
    @EnvironmentObject var model: GroupsModel
    @State private var routedDemo = false

    var body: some View {
        NavigationStack {
            switch app.phase {
            case .loading: ProgressView()
            case .signedOut: AuthView()
            case .needsScreenTime: ScreenTimeGateView()
            case .unpaired: PairingView()
            case .ready: HomeView()
            }
        }
        .fontDesign(.rounded)
        .tint(Theme.coral)
        .background(Theme.background)
        .task { await foreground() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await foreground() } } }
    }

    private func foreground() async {
        await app.refresh()
        if Demo.isOn {
            model.reload()
            await model.loadRemote(partnerID: app.partner?.id)
            router.incomingCount = Demo.requests.filter {
                $0.fromUser == app.partner?.id && $0.effectiveStatus() == .pending
            }.count
            routeDemoIfNeeded()
            return
        }
        await SyncService.shared.run()
        model.reload()
        if app.phase == .ready, let rows = try? await app.backend.requests() {
            router.incomingCount = rows.filter {
                $0.fromUser == app.partner?.id && $0.effectiveStatus() == .pending
            }.count
        }
        let store = SharedStore()
        if let ask = store.load(PendingAsk.self, key: SharedKey.pendingAsk) {
            store.remove(SharedKey.pendingAsk)
            if Date().timeIntervalSince(ask.createdAt) < 600, app.phase == .ready { router.sheet = .ask(ask.groupID) }
        }
    }

    private func routeDemoIfNeeded() {
        guard !routedDemo else { return }
        routedDemo = true
        switch Demo.shot {
        case "requests": router.tab = .requests
        case "feed": router.tab = .feed
        case "ask": router.sheet = .ask(nil)
        case "editor": router.demoEditor = Demo.myGroups.first
        default: router.tab = .groups
        }
    }
}
