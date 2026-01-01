import SwiftUI

struct ContentView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var showOnboarding = false

    var body: some View {
        MainTabView()
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-skip-onboarding") {
                    hasOnboarded = true
                    showOnboarding = false
                } else {
                    showOnboarding = !hasOnboarded || OnboardingProgressStore.hasProgress
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView {
                    hasOnboarded = true
                    showOnboarding = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: DataDeletionService.dataDeletedNotification)) { _ in
                // Data was deleted, show onboarding again
                hasOnboarded = false
                showOnboarding = true
            }
    }
}

#Preview {
    ContentView()
}
