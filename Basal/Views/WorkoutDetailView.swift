import SwiftUI
import HealthKit

struct WorkoutDetailView: View {
    let workout: WorkoutData
    @State private var effortLevel: Int? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                workoutHeader
                
                // Workout Details
                workoutDetailsSection
                
            }
            .padding(.bottom, 20)
        }
        .navigationTitle(workout.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Workout header with icon, name, and time
    private var workoutHeader: some View {
        // Create formatter outside the view builder
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        return VStack(spacing: 8) {
            // Icon and workout type
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 80, height: 80)
                
                Image(systemName: workout.iconName)
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            .padding(.top, 20)
            
            Text(workout.displayName)
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Open Goal")
                .font(.title3)
                .foregroundColor(.green)
            
            // Time range - using the formatter defined above
            Text("\(formatter.string(from: workout.startDate))–\(formatter.string(from: workout.endDate))")
                .foregroundColor(.gray)
                .padding(.top, 4)
            
            // Location
            HStack {
                Image(systemName: "location.fill")
                    .font(.caption)
                Text("New York")
                    .font(.body)
            }
            .foregroundColor(.gray)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }
    
    // Workout details section with metrics
    private var workoutDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Workout Details")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // Metrics grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                // Row 1: Workout Time and Elapsed Time
                if workout.shouldShowMetric(metric: .workoutTime) {
                    metricView(title: "Workout Time", value: workout.formattedDuration, color: .yellow)
                }
                
                if workout.shouldShowMetric(metric: .elapsedTime) {
                    metricView(title: "Elapsed Time", value: workout.formattedElapsedTime, color: .yellow)
                }
                
                // Row 2: Distance and Active Calories
                if workout.shouldShowMetric(metric: .distance), let distance = workout.formattedDistance {
                    metricView(title: "Distance", value: distance, color: .cyan)
                }
                
                if workout.shouldShowMetric(metric: .activeCalories), let activeCalories = workout.formattedActiveCalories {
                    metricView(title: "Active Calories", value: activeCalories, color: .red)
                }
                
                // Row 3: Total Calories and Elevation Gain
                if workout.shouldShowMetric(metric: .totalCalories), let totalCalories = workout.formattedCalories {
                    metricView(title: "Total Calories", value: totalCalories, color: .red)
                }
                
                if workout.shouldShowMetric(metric: .elevationGain), let elevation = workout.formattedElevationGain {
                    metricView(title: "Elevation Gain", value: elevation, color: .green)
                }
                
                // Row 4: Avg. Power and Avg. Cadence
                if workout.shouldShowMetric(metric: .power), let power = workout.formattedPower {
                    metricView(title: "Avg. Power", value: power, color: .green)
                }
                
                if workout.shouldShowMetric(metric: .cadence), let cadence = workout.formattedCadence {
                    metricView(title: "Avg. Cadence", value: cadence, color: .cyan)
                }
                
                // Row 5: Avg. Pace and Avg. Heart Rate
                if workout.shouldShowMetric(metric: .pace), let pace = workout.formattedPace {
                    metricView(title: "Avg. Pace", value: pace, color: .cyan)
                }
                
                if workout.shouldShowMetric(metric: .heartRate), let heartRate = workout.formattedHeartRate {
                    metricView(title: "Avg. Heart Rate", value: heartRate, color: .red)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
    
    // Helper view for individual metrics
    private func metricView(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 12)
                .padding(.leading, 12)
            
            Text(value)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(color)
                .padding(.leading, 12)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .trailing
        )
    }
}

#Preview {
    NavigationView {
        WorkoutDetailView(
            workout: WorkoutData(
                workoutType: .running,
                startDate: Date().addingTimeInterval(-3600),
                endDate: Date(),
                duration: 1695,
                totalEnergyBurned: 352,
                totalDistance: 5120,
                source: "Apple Watch",
                deviceType: "Apple Watch",
                workoutEvents: nil,
                metadata: nil,
                averageHeartRate: 167,
                activeEnergyBurned: 310,
                elevationGain: 7,
                averagePower: 217,
                averageCadence: 160,
                averagePace: 0.00553
            )
        )
    }
} 
