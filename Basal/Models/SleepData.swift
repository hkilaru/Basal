import Foundation
import SwiftUI

// Enum to represent different sleep stages
enum SleepStage: String, CaseIterable {
    case inBed = "In Bed"
    case awake = "Awake"
    case unspecified = "Asleep"
    case rem = "REM"
    case core = "Core"
    case deep = "Deep"
    
    var displayName: String {
        return self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .inBed:
            return "bed.double.fill"
        case .awake:
            return "eye.fill"
        case .unspecified:
            return "moon.fill"
        case .rem:
            return "sparkles"
        case .core:
            return "moon.zzz.fill"
        case .deep:
            return "moon.stars.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .inBed:
            return .gray
        case .awake:
            return .yellow
        case .unspecified:
            return .blue
        case .rem:
            return .purple
        case .core:
            return .blue
        case .deep:
            return .indigo
        }
    }
}

struct SleepInterval: Identifiable {
    let id = UUID()
    let stage: SleepStage
    let startDate: Date
    let endDate: Date
    let duration: Int // in seconds
    let source: String
    let deviceType: String
    
    var durationInMinutes: Int {
        return duration / 60
    }
    
    // Convert to the format expected by MetricView
    var asMetricSample: (value: Double, date: Date, source: String, deviceType: String) {
        return (value: Double(durationInMinutes), date: startDate, source: source, deviceType: deviceType)
    }
}

struct SleepSession {
    var intervals: [SleepInterval]
    
    var totalDuration: Int {
        return intervals.reduce(0) { $0 + $1.duration }
    }
}

// All sleep data
struct SleepData {
    var date: Date = Date()
    var startTime: Date = Date()
    var endTime: Date = Date()
    var awakeIntervals: [SleepInterval] = []
    var remIntervals: [SleepInterval] = []
    var coreIntervals: [SleepInterval] = []
    var deepIntervals: [SleepInterval] = []
    var totalSleepDuration: Int = 0 // in seconds
    
    var hasSleepData: Bool {
        return totalSleepDuration > 0
    }
    
    var formattedTotalSleepTime: String {
        let hours = totalSleepDuration / 3600
        let minutes = (totalSleepDuration % 3600) / 60
        
        if hours > 0 {
            return "\(hours)hr \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
    
    var formattedDateRange: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startTime)
        let endDay = calendar.startOfDay(for: endTime)
        
        if calendar.isDate(startDay, inSameDayAs: endDay) {
            return dateFormatter.string(from: startTime)
        } else {
            return "\(dateFormatter.string(from: startTime))–\(dateFormatter.string(from: endTime))"
        }
    }
    
    // Get all sleep stages with their total durations and convert to MetricView format
    var sleepStageMetrics: [(title: String, samples: [(value: Double, date: Date, source: String, deviceType: String)], icon: String, color: Color)] {
        return [
            (
                title: "Awake",
                samples: awakeIntervals.map { $0.asMetricSample },
                icon: SleepStage.awake.iconName,
                color: SleepStage.awake.color
            ),
            (
                title: "REM",
                samples: remIntervals.map { $0.asMetricSample },
                icon: SleepStage.rem.iconName,
                color: SleepStage.rem.color
            ),
            (
                title: "Core",
                samples: coreIntervals.map { $0.asMetricSample },
                icon: SleepStage.core.iconName,
                color: SleepStage.core.color
            ),
            (
                title: "Deep",
                samples: deepIntervals.map { $0.asMetricSample },
                icon: SleepStage.deep.iconName,
                color: SleepStage.deep.color
            )
        ]
    }
    
    // Get summary data for sleep stages
    var sleepStageSummary: [(title: String, count: Int, duration: Int, icon: String, color: Color)] {
        return [
            (
                title: "Awake",
                count: awakeIntervals.count,
                duration: awakeIntervals.reduce(0) { $0 + $1.duration },
                icon: SleepStage.awake.iconName,
                color: SleepStage.awake.color
            ),
            (
                title: "REM",
                count: remIntervals.count,
                duration: remIntervals.reduce(0) { $0 + $1.duration },
                icon: SleepStage.rem.iconName,
                color: SleepStage.rem.color
            ),
            (
                title: "Core",
                count: coreIntervals.count,
                duration: coreIntervals.reduce(0) { $0 + $1.duration },
                icon: SleepStage.core.iconName,
                color: SleepStage.core.color
            ),
            (
                title: "Deep",
                count: deepIntervals.count,
                duration: deepIntervals.reduce(0) { $0 + $1.duration },
                icon: SleepStage.deep.iconName,
                color: SleepStage.deep.color
            )
        ].filter { $0.count > 0 }
    }
} 
