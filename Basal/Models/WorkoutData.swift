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
        case .americanFootball:
            return "American Football"
        case .archery:
            return "Archery"
        case .australianFootball:
            return "Australian Football"
        case .badminton:
            return "Badminton"
        case .barre:
            return "Barre"
        case .baseball:
            return "Baseball"
        case .basketball:
            return "Basketball"
        case .bowling:
            return "Bowling"
        case .boxing:
            return "Boxing"
        case .climbing:
            return "Climbing"
        case .cooldown:
            return "Cooldown"
        case .coreTraining:
            return "Core Training"
        case .cricket:
            return "Cricket"
        case .crossCountrySkiing:
            return "Cross Country Skiing"
        case .crossTraining:
            return "Cross Training"
        case .curling:
            return "Curling"
        case .cycling:
            return "Cycling"
        case .dance:
            return "Dance"
        case .danceInspiredTraining:
            return "Dance Training"
        case .discSports:
            return "Disc Sports"
        case .downhillSkiing:
            return "Downhill Skiing"
        case .elliptical:
            return "Elliptical"
        case .equestrianSports:
            return "Equestrian Sports"
        case .fencing:
            return "Fencing"
        case .fishing:
            return "Fishing"
        case .fitnessGaming:
            return "Fitness Gaming"
        case .flexibility:
            return "Flexibility"
        case .functionalStrengthTraining:
            return "Functional Strength Training"
        case .golf:
            return "Golf"
        case .gymnastics:
            return "Gymnastics"
        case .handCycling:
            return "Hand Cycling"
        case .handball:
            return "Handball"
        case .highIntensityIntervalTraining:
            return "High Intensity Interval Training"
        case .hiking:
            return "Hiking"
        case .hockey:
            return "Hockey"
        case .hunting:
            return "Hunting"
        case .jumpRope:
            return "Jump Rope"
        case .kickboxing:
            return "Kickboxing"
        case .lacrosse:
            return "Lacrosse"
        case .martialArts:
            return "Martial Arts"
        case .mindAndBody:
            return "Mindfulness"
        case .mixedCardio:
            return "Mixed Cardio"
        case .mixedMetabolicCardioTraining:
            return "Mixed Metabolic Cardio"
        case .other:
            return "Other Workout"
        case .paddleSports:
            return "Paddle Sports"
        case .pickleball:
            return "Pickleball"
        case .pilates:
            return "Pilates"
        case .play:
            return "Play"
        case .preparationAndRecovery:
            return "Preparation & Recovery"
        case .racquetball:
            return "Racquetball"
        case .rowing:
            return "Rowing"
        case .rugby:
            return "Rugby"
        case .running:
            return "Running"
        case .sailing:
            return "Sailing"
        case .skatingSports:
            return "Skating"
        case .snowSports:
            return "Snow Sports"
        case .snowboarding:
            return "Snowboarding"
        case .soccer:
            return "Soccer"
        case .socialDance:
            return "Social Dance"
        case .softball:
            return "Softball"
        case .squash:
            return "Squash"
        case .stairClimbing:
            return "Stair Stepper"
        case .stairs:
            return "Stairs"
        case .stepTraining:
            return "Step Training"
        case .surfingSports:
            return "Surfing"
        case .swimming:
            return "Swimming"
        case .tableTennis:
            return "Table Tennis"
        case .taiChi:
            return "Tai Chi"
        case .tennis:
            return "Tennis"
        case .trackAndField:
            return "Track & Field"
        case .traditionalStrengthTraining:
            return "Traditional Strength Training"
        case .volleyball:
            return "Volleyball"
        case .walking:
            return "Walking"
        case .waterFitness:
            return "Water Fitness"
        case .waterPolo:
            return "Water Polo"
        case .waterSports:
            return "Water Sports"
        case .wheelchairRunPace:
            return "Wheelchair Run"
        case .wheelchairWalkPace:
            return "Wheelchair Walk"
        case .wrestling:
            return "Wrestling"
        case .yoga:
            return "Yoga"
        case .cardioDance:
            return "Cardio dance"
        case .swimBikeRun:
            return "Swim, bike, run"
        case .transition:
            return "Workout"
        case .underwaterDiving:
            return "Underwater Diving"
        @unknown default:
            return "Workout"
        }
    }
    
    // Helper function to get icon name for workout type
private func workoutTypeIconName(_ type: HKWorkoutActivityType) -> String {
    switch type {
    case .americanFootball:
        return "figure.american.football"
    case .archery:
        return "figure.archery"
    case .australianFootball:
        return "figure.australian.football"
    case .badminton:
        return "figure.badminton"
    case .barre:
        return "figure.barre"
    case .baseball:
        return "figure.baseball"
    case .basketball:
        return "figure.basketball"
    case .bowling:
        return "figure.bowling"
    case .boxing:
        return "figure.boxing"
    case .climbing:
        return "figure.climbing"
    case .cooldown:
        return "figure.cooldown"
    case .coreTraining:
        return "figure.core.training"
    case .cricket:
        return "figure.cricket"
    case .crossCountrySkiing:
        return "figure.cross.country.skiing"
    case .crossTraining:
        return "figure.cross.training"
    case .curling:
        return "figure.curling"
    case .cycling:
        return "figure.indoor.cycle"
    case .dance:
        return "figure.dance"
    case .danceInspiredTraining:
        return "figure.dance"
    case .discSports:
        return "figure.disc.sports"
    case .downhillSkiing:
        return "figure.skiing.downhill"
    case .elliptical:
        return "figure.elliptical"
    case .equestrianSports:
        return "figure.equestrian.sports"
    case .fencing:
        return "figure.fencing"
    case .fishing:
        return "figure.fishing"
    case .fitnessGaming:
        return "figure.gaming"
    case .flexibility:
        return "figure.flexibility"
    case .functionalStrengthTraining:
        return "figure.strengthtraining.functional"
    case .golf:
        return "figure.golf"
    case .gymnastics:
        return "figure.gymnastics"
    case .handCycling:
        return "figure.hand.cycling"
    case .handball:
        return "figure.handball"
    case .highIntensityIntervalTraining:
        return "figure.highintensity.intervaltraining"
    case .hiking:
        return "figure.hiking"
    case .hockey:
        return "figure.hockey"
    case .hunting:
        return "figure.hunting"
    case .jumpRope:
        return "figure.jumprope"
    case .kickboxing:
        return "figure.kickboxing"
    case .lacrosse:
        return "figure.lacrosse"
    case .martialArts:
        return "figure.martial.arts"
    case .mindAndBody:
        return "figure.mind.and.body"
    case .mixedCardio:
        return "figure.mixed.cardio"
    case .mixedMetabolicCardioTraining:
        return "figure.mixed.cardio"
    case .other:
        return "figure.questionmark"
    case .paddleSports:
        return "figure.paddle.sports"
    case .pickleball:
        return "figure.pickleball"
    case .pilates:
        return "figure.pilates"
    case .play:
        return "figure.play"
    case .preparationAndRecovery:
        return "figure.preparation.and.recovery"
    case .racquetball:
        return "figure.racquetball"
    case .rowing:
        return "figure.rower"
    case .rugby:
        return "figure.rugby"
    case .running:
        return "figure.run"
    case .sailing:
        return "figure.sailing"
    case .skatingSports:
        return "figure.skating"
    case .snowSports:
        return "figure.snow.sports"
    case .snowboarding:
        return "figure.snowboarding"
    case .soccer:
        return "figure.soccer"
    case .socialDance:
        return "figure.socialdance"
    case .softball:
        return "figure.softball"
    case .squash:
        return "figure.squash"
    case .stairClimbing:
        return "figure.stair.stepper"
    case .stairs:
        return "figure.stairs"
    case .stepTraining:
        return "figure.step.training"
    case .surfingSports:
        return "figure.surfing"
    case .swimming:
        return "figure.swimming"
    case .tableTennis:
        return "figure.table.tennis"
    case .taiChi:
        return "figure.taichi"
    case .tennis:
        return "figure.tennis"
    case .trackAndField:
        return "figure.track.and.field"
    case .traditionalStrengthTraining:
        return "figure.strengthtraining.traditional"
    case .volleyball:
        return "figure.volleyball"
    case .walking:
        return "figure.walk"
    case .waterFitness:
        return "figure.water.fitness"
    case .waterPolo:
        return "figure.waterpolo"
    case .waterSports:
        return "figure.water.sports"
    case .wheelchairRunPace:
        return "figure.wheelchair.race"
    case .wheelchairWalkPace:
        return "figure.wheelchair"
    case .wrestling:
        return "figure.wrestling"
    case .yoga:
        return "figure.yoga"
    case .cardioDance:
        return "figure.dance"
    case .swimBikeRun:
        return "figure.mixed.cardio"
    case .underwaterDiving:
        return "figure.open.water.swim"
    case .transition:
        return "questionmark"
    @unknown default:
        return "questionmark"
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
    var selectedDate: Date = Date()
    
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
    
    var workoutsForSelectedDate: [WorkoutData] {
        let calendar = Calendar.current
        let startOfSelectedDay = calendar.startOfDay(for: selectedDate)
        
        return workouts.filter { calendar.isDate($0.startDate, inSameDayAs: startOfSelectedDay) }
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
