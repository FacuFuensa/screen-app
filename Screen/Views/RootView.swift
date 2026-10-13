import ScreenCore
import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: Router
    @EnvironmentObject var model: GroupsModel
    @EnvironmentObject var activity: ActivityModel
    @State private var routedDemo = false

    var body: some View {
        Group {
            switch app.phase {
            case .loading: ProgressView()
            case .signedOut: NavigationStack { AuthView() }
            case .needsScreenTime: NavigationStack { ScreenTimeGateView() }
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
            await activity.load()
            await model.loadRemote(partnerID: app.partner?.id)
            routeDemoIfNeeded()
            return
        }
        await SyncService.shared.run()
        model.reload()
        if app.phase == .ready { await activity.load() }
        let store = SharedStore()
        if let ask = store.load(PendingAsk.self, key: SharedKey.pendingAsk) {
            store.remove(SharedKey.pendingAsk)
            if Date().timeIntervalSince(ask.createdAt) < 600, app.phase == .ready, app.isPaired {
                router.sheet = .ask(ask.groupID)
            }
        }
    }

    private func routeDemoIfNeeded() {
        guard !routedDemo else { return }
        routedDemo = true
        switch Demo.shot {
        case "dupla", "dupla-sin-pareja": router.tab = .partner
        case "ask": router.sheet = .ask(nil)
        case "editor-endurecer":
            var draft = Demo.myGroups[0]; draft.dailyMinutes = 30
            router.demoEditor = DemoEditorRequest(original: Demo.myGroups[0], draft: draft)
        case "editor-aflojar":
            var draft = Demo.myGroups[0]; draft.dailyMinutes = 75
            router.demoEditor = DemoEditorRequest(original: Demo.myGroups[0], draft: draft)
        case "editor-pendiente":
            router.demoEditor = DemoEditorRequest(original: Demo.myGroups[1], draft: Demo.myGroups[1])
        default: router.tab = .me
        }
    }
}
