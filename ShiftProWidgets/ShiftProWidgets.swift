import WidgetKit
import SwiftUI

@main
struct ShiftProWidgetBundle: WidgetBundle {
    var body: some Widget {
        CurrentShiftWidget()
        NextShiftWidget()
        HoursSummaryWidget()
        ScheduleOverviewWidget()
        QuickActionsWidget()
    }
}
