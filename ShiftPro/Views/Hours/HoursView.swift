import SwiftUI

/// Entry point for hours tracking - delegates to HoursDashboard
struct HoursView: View {
    var body: some View {
        HoursDashboard()
    }
}

#Preview {
    NavigationStack {
        HoursView()
    }
}
