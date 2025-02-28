//
//  WorkoutsSection.swift
//  Basal
//
//  Created by Harish Kilaru on 2/28/25.
//

import SwiftUI

struct WorkoutsSection: View {
    let workouts: [WorkoutData]
    
    var body: some View {
        if !workouts.isEmpty {
            Section {
                ForEach(workouts) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        workoutRow(workout)
                    }
                }
            } header: {
                Text("Workouts")
            }
        }
    }
    
    private func workoutRow(_ workout: WorkoutData) -> some View {
        // Create formatter outside the view builder
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        return HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 40, height: 40)
                
                Image(systemName: workout.iconName)
                    .foregroundColor(.green)
                    .font(.system(size: 20))
            }
            
            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.displayName)
                    .font(.body)
                
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
            
            // Time of workout
            Text(formatter.string(from: workout.startDate))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
} 