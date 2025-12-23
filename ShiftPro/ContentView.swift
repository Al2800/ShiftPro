import SwiftUI

struct ContentView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var showOnboarding = false

    var body: some View {
        MainTabView()
            .onAppear {
                showOnboarding = !hasOnboarded
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView {
                    hasOnboarded = true
                    showOnboarding = false
                }
            }
    }
}

#Preview {
    ContentView()
}
