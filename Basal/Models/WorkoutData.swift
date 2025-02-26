import Foundation
import HealthKit

// Struct to represent a single workout
struct WorkoutData: Identifiable {
    let id = UUID()
    let workoutType: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let totalEnergyBurned: Double?
    let totalDistance: Double?
    let source: String
    let deviceType: String
    let workoutEvents: [HKWorkoutEvent]?
    let metadata: [String: Any]?
    
    // Additional metrics that might be available
    var averageHeartRate: Double?
    var activeEnergyBurned: Double?
    var elevationGain: Double?
    var averagePower: Double?
    var averageCadence: Double?
    var averagePace: Double?
    
    // Computed properties for formatted display
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedElapsedTime: String {
        let elapsed = endDate.timeIntervalSince(startDate)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedDistance: String? {
        guard let distance = totalDistance else { return nil }
        
        // Format based on workout type
        switch workoutType {
        case .running, .walking, .hiking, .cycling:
            // Display in miles with 2 decimal places
            return String(format: "%.2f", distance / 1609.34) + "MI"
        case .swimming:
            // Display in yards
            return String(format: "%.0f", distance * 1.09361) + "YD"
        default:
            // Default to miles for other activities
            return String(format: "%.2f", distance / 1609.34) + "MI"
        }
    }
    
    var formattedCalories: String? {
        guard let calories = totalEnergyBurned else { return nil }
        return "\(Int(calories))CAL"
    }
    
    var formattedActiveCalories: String? {
        guard let activeCalories = activeEnergyBurned else { return nil }
        return "\(Int(activeCalories))CAL"
    }
    
    var formattedElevationGain: String? {
        guard let elevation = elevationGain else { return nil }
        return "\(Int(elevation))FT"
    }
    
    var formattedPower: String? {
        guard let power = averagePower else { return nil }
        return "\(Int(power))W"
    }
    
    var formattedCadence: String? {
        guard let cadence = averageCadence else { return nil }
        return "\(Int(cadence))SPM"
    }
    
    var formattedPace: String? {
        guard let pace = averagePace else { return nil }
        
        // Pace is in seconds per meter, convert to minutes per mile
        let paceMinPerMile = pace * 1609.34 / 60
        let minutes = Int(paceMinPerMile)
        let seconds = Int((paceMinPerMile - Double(minutes)) * 60)
        
        return String(format: "%d'%02d\"/MI", minutes, seconds)
    }
    
    var formattedHeartRate: String? {
        guard let heartRate = averageHeartRate else { return nil }
        return "\(Int(heartRate))BPM"
    }
    
    var displayName: String {
        return workoutTypeDisplayName(workoutType)
    }
    
    var iconName: String {
        return workoutTypeIconName(workoutType)
    }
    
    // Helper function to get display name for workout type
    private func workoutTypeDisplayName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:
            return "Outdoor Run"
        case .walking:
            return "Outdoor Walk"
        case .cycling:
            return "Outdoor Cycle"
        case .swimming:
            return "Pool Swim"
        case .functionalStrengthTraining:
            return "Functional Strength Training"
        case .traditionalStrengthTraining:
            return "Traditional Strength Training"
        case .hiking:
            return "Hiking"
        case .yoga:
            return "Yoga"
        case .dance:
            return "Dance"
        case .mindAndBody:
            return "Mindfulness"
        case .highIntensityIntervalTraining:
            return "HIIT"
        default:
            return "Workout"
        }
    }
    
    // Helper function to get icon name for workout type
    private func workoutTypeIconName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:
            return "figure.run"
        case .walking:
            return "figure.walk"
        case .cycling:
            return "figure.outdoor.cycle"
        case .swimming:
            return "figure.pool.swim"
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return "figure.strengthtraining.traditional"
        case .hiking:
            return "figure.hiking"
        case .yoga, .mindAndBody:
            return "figure.mind.and.body"
        case .dance:
            return "figure.dance"
        case .highIntensityIntervalTraining:
            return "figure.hiit"
        default:
            return "figure.mixed.cardio"
        }
    }
    
    // Helper function to determine if a metric should be shown for this workout type
    func shouldShowMetric(metric: WorkoutMetric) -> Bool {
        switch metric {
        case .distance:
            // Show distance for cardio activities
            return [.running, .walking, .cycling, .swimming, .hiking].contains(workoutType)
        case .elevationGain:
            // Show elevation for activities where it makes sense
            return [.running, .walking, .cycling, .hiking].contains(workoutType)
        case .pace:
            // Show pace for running, walking, hiking
            return [.running, .walking, .hiking].contains(workoutType)
        case .power:
            // Show power for cycling and strength training
            return [.cycling, .functionalStrengthTraining, .traditionalStrengthTraining].contains(workoutType)
        case .cadence:
            // Show cadence for running, cycling
            return [.running, .cycling].contains(workoutType)
        default:
            // Show other metrics for all workout types
            return true
        }
    }
}

// Enum to represent different workout metrics
enum WorkoutMetric {
    case workoutTime
    case elapsedTime
    case distance
    case activeCalories
    case totalCalories
    case elevationGain
    case power
    case cadence
    case pace
    case heartRate
}

// Collection of workouts
struct WorkoutCollection {
    var workouts: [WorkoutData] = []
    
    var hasWorkouts: Bool {
        return !workouts.isEmpty
    }
    
    // Group workouts by date
    func groupedByDate() -> [Date: [WorkoutData]] {
        let calendar = Calendar.current
        
        return Dictionary(grouping: workouts) { workout in
            calendar.startOfDay(for: workout.startDate)
        }
    }
    
    // Get workouts for today
    var todaysWorkouts: [WorkoutData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return workouts.filter { calendar.isDate($0.startDate, inSameDayAs: today) }
    }
    
    // Get workouts for a specific month
    func workoutsForMonth(_ date: Date) -> [WorkoutData] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        
        return workouts.filter {
            let workoutComponents = calendar.dateComponents([.year, .month], from: $0.startDate)
            return workoutComponents.year == components.year && workoutComponents.month == components.month
        }
    }
} 