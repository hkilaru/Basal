import XCTest
import HealthKit
@testable import Basal

final class WorkoutDataTests: XCTestCase {
    
    func testWorkoutDataFormatting() {
        // Create a test workout
        let workout = WorkoutData(
            workoutType: .running,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600), // 1 hour
            duration: 3600,
            totalEnergyBurned: 500,
            totalDistance: 8046.72, // 5 miles
            source: "Apple Watch",
            deviceType: "Apple Watch",
            workoutEvents: nil,
            metadata: nil,
            averageHeartRate: 150,
            activeEnergyBurned: 450,
            elevationGain: 100,
            averagePower: 200,
            averageCadence: 170,
            averagePace: 0.00447 // ~7:12 min/mile
        )
        
        // Test duration formatting
        XCTAssertEqual(workout.formattedDuration, "1:00:00")
        
        // Test distance formatting
        XCTAssertEqual(workout.formattedDistance, "5.00MI")
        
        // Test calories formatting
        XCTAssertEqual(workout.formattedCalories, "500CAL")
        XCTAssertEqual(workout.formattedActiveCalories, "450CAL")
        
        // Test elevation gain formatting
        XCTAssertEqual(workout.formattedElevationGain, "100FT")
        
        // Test power formatting
        XCTAssertEqual(workout.formattedPower, "200W")
        
        // Test cadence formatting
        XCTAssertEqual(workout.formattedCadence, "170SPM")
        
        // Test pace formatting
        XCTAssertEqual(workout.formattedPace, "7'12\"/MI")
        
        // Test heart rate formatting
        XCTAssertEqual(workout.formattedHeartRate, "150BPM")
        
        // Test display name
        XCTAssertEqual(workout.displayName, "Outdoor Run")
        
        // Test icon name
        XCTAssertEqual(workout.iconName, "figure.run")
        
        // Test metric visibility
        XCTAssertTrue(workout.shouldShowMetric(metric: .distance))
        XCTAssertTrue(workout.shouldShowMetric(metric: .pace))
        XCTAssertTrue(workout.shouldShowMetric(metric: .cadence))
        XCTAssertFalse(workout.shouldShowMetric(metric: .power))
    }
    
    func testWorkoutCollection() {
        // Create a collection with workouts from different days
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        
        let workout1 = WorkoutData(
            workoutType: .running,
            startDate: today,
            endDate: today.addingTimeInterval(3600),
            duration: 3600,
            totalEnergyBurned: 500,
            totalDistance: 8046.72,
            source: "Apple Watch",
            deviceType: "Apple Watch",
            workoutEvents: nil,
            metadata: nil
        )
        
        let workout2 = WorkoutData(
            workoutType: .walking,
            startDate: yesterday,
            endDate: yesterday.addingTimeInterval(1800),
            duration: 1800,
            totalEnergyBurned: 200,
            totalDistance: 3218.69,
            source: "Apple Watch",
            deviceType: "Apple Watch",
            workoutEvents: nil,
            metadata: nil
        )
        
        let workout3 = WorkoutData(
            workoutType: .functionalStrengthTraining,
            startDate: lastWeek,
            endDate: lastWeek.addingTimeInterval(2700),
            duration: 2700,
            totalEnergyBurned: 350,
            totalDistance: nil,
            source: "Apple Watch",
            deviceType: "Apple Watch",
            workoutEvents: nil,
            metadata: nil
        )
        
        var collection = WorkoutCollection()
        collection.workouts = [workout1, workout2, workout3]
        
        // Test hasWorkouts
        XCTAssertTrue(collection.hasWorkouts)
        
        // Test todaysWorkouts
        XCTAssertEqual(collection.todaysWorkouts.count, 1) // Ensure only today's workout is counted
        XCTAssertEqual(collection.todaysWorkouts.first?.workoutType, .running) // Ensure it's the correct workout
        
        // Test groupedByDate
        let grouped = collection.groupedByDate()
        XCTAssertEqual(grouped.count, 3) // Three different days
        
        // Test workoutsForMonth
        let thisMonth = collection.workoutsForMonth(today)
        XCTAssertEqual(thisMonth.count, 3) // All workouts are in the same month in this test
    }
} 