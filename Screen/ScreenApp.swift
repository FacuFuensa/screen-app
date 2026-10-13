import SwiftUI

@main
struct ScreenApp: App {
    @StateObject private var app = AppState()
    @StateObject private var router = Router.shared

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(app).environmentObject(router)
        }
    }
}
