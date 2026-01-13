import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var showOnboarding = false

    var body: some View {
        MainTabView()
            .onAppear {
                // Demo mode: seed data and skip onboarding
                if DemoDataSeeder.isDemoMode {
                    DemoDataSeeder.seedIfNeeded(context: modelContext)
                    hasOnboarded = true
                    showOnboarding = false
                } else if ProcessInfo.processInfo.arguments.contains("-skip-onboarding") {
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
            .onReceive(NotificationCenter.default.publisher(for: .resumeOnboarding)) { _ in
                showOnboarding = true
            }
    }
}

extension Notification.Name {
    static let resumeOnboarding = Notification.Name("resumeOnboarding")
}

#Preview {
    ContentView()
}
