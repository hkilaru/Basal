import SwiftUI
import HealthKit

struct WorkoutSessionsView: View {
    @EnvironmentObject var hkManager: HKManager
    @State private var selectedFilter: WorkoutFilter = .all
    @State private var currentMonth = Date()
    
    // Formatters as properties
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    enum WorkoutFilter: String, CaseIterable {
        case all = "All"
        case workouts = "Workouts"
        case mindfulness = "Mindfulness"
        case walking = "Walking"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WorkoutFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                        }) {
                            Text(filter.rawValue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedFilter == filter ? Color.green : Color.gray.opacity(0.2))
                                .foregroundColor(selectedFilter == filter ? .black : .white)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            
            // Month header
            VStack(alignment: .leading, spacing: 8) {
                Text(monthFormatter.string(from: currentMonth))
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top, 10)
            }
            
            // Workouts list
            ScrollView {
                LazyVStack(spacing: 12) {
                    let filteredWorkouts = filterWorkouts(hkManager.workoutCollection.workoutsForMonth(currentMonth))
                    
                    if filteredWorkouts.isEmpty {
                        Text("No workouts found for this month")
                            .foregroundColor(.gray)
                            .padding(.top, 40)
                    } else {
                        ForEach(filteredWorkouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                workoutRow(workout)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: 
            Button {
                // Share action
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.green)
            }
        )
    }
    
    // Filter workouts based on selected filter
    private func filterWorkouts(_ workouts: [WorkoutData]) -> [WorkoutData] {
        switch selectedFilter {
        case .all:
            return workouts
        case .workouts:
            return workouts.filter { 
                ![.walking, .mindAndBody].contains($0.workoutType)
            }
        case .mindfulness:
            return workouts.filter { 
                $0.workoutType == .mindAndBody || $0.workoutType == .yoga
            }
        case .walking:
            return workouts.filter { 
                $0.workoutType == .walking
            }
        }
    }
    
    // Workout row view
    private func workoutRow(_ workout: WorkoutData) -> some View {
        return HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 50, height: 50)
                
                Image(systemName: workout.iconName)
                    .foregroundColor(.green)
                    .font(.system(size: 24))
            }
            
            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Show either distance or calories based on workout type
                if let distance = workout.formattedDistance {
                    Text(distance)
                        .font(.title2)
                        .foregroundColor(.green)
                } else if let calories = workout.formattedCalories {
                    Text(calories)
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Date
            if Calendar.current.isDateInToday(workout.startDate) {
                Text("Today")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                Text(dayFormatter.string(from: workout.startDate))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

#Preview {
    NavigationView {
        WorkoutSessionsView()
            .environmentObject(HKManager())
    }
} 