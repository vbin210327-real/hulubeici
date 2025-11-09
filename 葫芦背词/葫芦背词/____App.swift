import SwiftUI

@main
struct HuluBeiciApp: App {
    @StateObject private var sessionStore = AuthSessionStore()
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showGuide: Bool = false
    @State private var showGuideOverlay: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingView {
                        showOnboarding = false
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    }
                } else {
                    if APIConfig.AppSyncConfig.backendEnabled {
                        if let session = sessionStore.session {
                            ZStack {
                                ContentView(session: session)
                                    .environmentObject(sessionStore)
                                    .onAppear {
                                        if !UserDefaults.standard.bool(forKey: "hasSeenGuide") {
                                            // First show overlay after 2s
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                                withAnimation(.easeIn(duration: 0.4)) {
                                                    showGuideOverlay = true
                                                }
                                            }
                                            // Then show Guide after 2.3s (0.3s after overlay)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                                                withAnimation(.spring(response: 1.0, dampingFraction: 0.75)) {
                                                    showGuide = true
                                                }
                                            }
                                        }
                                    }

                                if showGuideOverlay {
                                    Color.black.opacity(0.3)
                                        .ignoresSafeArea()
                                        .transition(.opacity)
                                        .onTapGesture {
                                            withAnimation(.easeOut(duration: 0.4)) {
                                                showGuide = false
                                                showGuideOverlay = false
                                            }
                                            UserDefaults.standard.set(true, forKey: "hasSeenGuide")
                                        }
                                }

                                if showGuide {
                                    GuideView(onDismiss: {
                                        withAnimation(.easeOut(duration: 0.4)) {
                                            showGuide = false
                                            showGuideOverlay = false
                                        }
                                        UserDefaults.standard.set(true, forKey: "hasSeenGuide")
                                    })
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                        } else {
                            SignInView()
                                .environmentObject(sessionStore)
                        }
                    } else {
                        // iCloud-only mode: show app without email login
                        let localSession = AuthSession(
                            accessToken: "icloud-local",
                            refreshToken: "icloud-local",
                            expiresAt: Date().addingTimeInterval(60*60*24*365*10),
                            userId: "icloud",
                            email: nil
                        )
                        ZStack {
                            ContentView(session: localSession)
                                .environmentObject(sessionStore)
                                .onAppear {
                                    if !UserDefaults.standard.bool(forKey: "hasSeenGuide") {
                                        // First show overlay after 2s
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                            withAnimation(.easeIn(duration: 0.4)) {
                                                showGuideOverlay = true
                                            }
                                        }
                                        // Then show Guide after 2.3s (0.3s after overlay)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                                            withAnimation(.spring(response: 1.0, dampingFraction: 0.75)) {
                                                showGuide = true
                                            }
                                        }
                                    }
                                }

                            if showGuideOverlay {
                                Color.black.opacity(0.3)
                                    .ignoresSafeArea()
                                    .transition(.opacity)
                                    .onTapGesture {
                                        withAnimation(.easeOut(duration: 0.4)) {
                                            showGuide = false
                                            showGuideOverlay = false
                                        }
                                        UserDefaults.standard.set(true, forKey: "hasSeenGuide")
                                    }
                            }

                            if showGuide {
                                GuideView(onDismiss: {
                                    withAnimation(.easeOut(duration: 0.4)) {
                                        showGuide = false
                                        showGuideOverlay = false
                                    }
                                    UserDefaults.standard.set(true, forKey: "hasSeenGuide")
                                })
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
        }
    }
}
