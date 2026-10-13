import SwiftUI

@main
struct ScreenApp: App {
    @StateObject private var app = AppState()
    @StateObject private var router = Router.shared
    @StateObject private var groups = GroupsModel()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(app).environmentObject(router).environmentObject(groups)
        }
    }
}
