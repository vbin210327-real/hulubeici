import SwiftUI

@main
struct HuluBeiciApp: App {
    @StateObject private var sessionStore = AuthSessionStore()

    var body: some Scene {
        WindowGroup {
            if let session = sessionStore.session {
                ContentView(session: session)
                    .environmentObject(sessionStore)
            } else {
                SignInView()
                    .environmentObject(sessionStore)
            }
        }
    }
}
