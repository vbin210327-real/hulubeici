import SwiftUI

@main
struct HuluBeiciApp: App {
    @StateObject private var sessionStore = AuthSessionStore()
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingView {
                        showOnboarding = false
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    }
                } else {
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
    }
}
