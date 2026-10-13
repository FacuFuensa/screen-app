import SwiftUI

@main
struct ScreenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppState()
    @StateObject private var router = Router.shared
    @StateObject private var groups = GroupsModel()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(app).environmentObject(router).environmentObject(groups)
        }
    }
}
