import SwiftUI

/// The four sections of the main window's sidebar.
enum AppSection: String, CaseIterable, Identifiable {
    case timer, tasks, stats, sounds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: "Timer"
        case .tasks: "Tasks"
        case .stats: "Stats"
        case .sounds: "Sounds"
        }
    }

    var symbol: String {
        switch self {
        case .timer: "timer"
        case .tasks: "checklist"
        case .stats: "chart.bar.fill"
        case .sounds: "speaker.wave.2.fill"
        }
    }
}
