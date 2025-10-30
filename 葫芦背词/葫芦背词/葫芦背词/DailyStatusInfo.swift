import SwiftUI

// Lightweight data model for the "今日状态" card.
// Matches usage in ContentView.todaySubtitle and ProfileInfoCard.
struct DailyStatusInfo {
    let subtitle: String
    let badge: String?
    let icon: String
    let accent: Color
}