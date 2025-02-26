//
//  SummaryView.swift
//  Basal
//
//  Created by Harish Kilaru on 2/24/25.
//

import SwiftUI
import HealthKit

struct SummaryView: View {
    @EnvironmentObject var hkManager: HKManager
    @State private var showWelcomeSheet = false
    
    // Define units and icons for each metric
    private let metricInfo: [String: (unit: String, icon: String, color: Color, title: String)] = [
        "Steps": ("steps", "figure.walk", .green, "STEPS"),
        "Heart Rate": ("BPM", "heart.fill", .red, "BEATS PER MINUTE"),
        "Active Energy": ("kcal", "flame.fill", .orange, "ACTIVE ENERGY"),
        "Resting Heart Rate": ("BPM", "heart.circle.fill", .pink, "RESTING HEART RATE"),
        "Heart Rate Variability": ("ms", "waveform.path.ecg", .purple, "HEART RATE VARIABILITY"),
        "Height": ("cm", "person.fill", .blue, "HEIGHT"),
        "Body Mass": ("kg", "scalemass.fill", .green, "BODY MASS"),
        "Sleep": ("", "bed.double.fill", .blue, "SLEEP")
    ]
    
    var body: some View {
        NavigationView {
            List {
                // Sleep section
                Section {
                    if hkManager.sleepData.hasSleepData {
                        NavigationLink {
                            SleepSummaryView(sleepData: hkManager.sleepData)
                        } label: {
                            sleepRow()
                        }
                    } else {
                        sleepRow()
                    }
                } header: {
                    Text("Sleep")
                }
                
                // Workouts section
                if !hkManager.workoutCollection.todaysWorkouts.isEmpty {
                    Section {
                        ForEach(hkManager.workoutCollection.todaysWorkouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                workoutRow(workout)
                            }
                        }
                    } header: {
                        Text("Today's Workouts")
                    }
                }
                
                // Health metrics section
                Section {
                    ForEach(Array(hkManager.healthData.keys.sorted().filter { $0 != "Sleep" }), id: \.self) { metric in
                        if hkManager.timeSeriesMetrics.contains(metric) {
                            // Navigation link for time-series metrics
                            NavigationLink {
                                MetricView(
                                    title: metricInfo[metric]?.title ?? metric.uppercased(),
                                    samples: samplesFor(metric: metric),
                                    unit: metricInfo[metric]?.unit ?? "",
                                    icon: metricInfo[metric]?.icon ?? "questionmark.circle",
                                    color: metricInfo[metric]?.color ?? .gray
                                )
                            } label: {
                                metricRow(for: metric, value: displayValueFor(metric: metric))
                            }
                        } else {
                            // Regular row for other metrics
                            metricRow(for: metric, value: displayValueFor(metric: metric))
                        }
                    }
                } header: {
                    Text("Health Metrics")
                }
            }
            .navigationTitle("Health Data")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await hkManager.fetchTodaysData()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.blue)
                    }
                    
                    Button {
                        showWelcomeSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showWelcomeSheet) {
                WelcomeView(isWelcomeSheetPresented: $showWelcomeSheet)
                    .environmentObject(hkManager)
            }
        }
    }
    
    // Sleep row with special formatting
    private func sleepRow() -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "bed.double.fill")
                .foregroundStyle(.blue)
                .font(.system(size: 24))
                .frame(width: 32, height: 32)
            
            // Sleep info
            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep")
                    .font(.body)
                
                if hkManager.sleepData.hasSleepData {
                    Text(hkManager.sleepData.formattedDateRange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Value
            if hkManager.sleepData.hasSleepData {
                Text(hkManager.sleepData.formattedTotalSleepTime)
                    .font(.headline)
                    .foregroundColor(.primary)
            } else {
                Text("No Data")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // Helper function to get the display value for a metric
    private func displayValueFor(metric: String) -> Double {
        switch metric {
        case "Heart Rate":
            return hkManager.latestHeartRate
        case "Heart Rate Variability":
            return hkManager.latestHRV
        default:
            return hkManager.healthData[metric] ?? 0
        }
    }
    
    // Helper function to get samples for a metric
    private func samplesFor(metric: String) -> [(value: Double, date: Date, source: String, deviceType: String)] {
        switch metric {
        case "Heart Rate":
            return hkManager.heartRateSamples
        case "Steps":
            return hkManager.stepsSamples
        case "Heart Rate Variability":
            return hkManager.hrvSamples
        default:
            return []
        }
    }
    
    // Helper function to create consistent metric rows
    private func metricRow(for metric: String, value: Double) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: metricInfo[metric]?.icon ?? "questionmark.circle")
                .foregroundStyle(metricInfo[metric]?.color ?? .gray)
                .font(.system(size: 24))
                .frame(width: 32, height: 32)
            
            // Metric name
            Text(metric)
                .font(.body)
            
            Spacer()
            
            // Value with unit
            VStack(alignment: .trailing) {
                Text("\(value, specifier: "%.0f")")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(metricInfo[metric]?.unit ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // Helper to create workout rows
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

#Preview {
    SummaryView()
        .environmentObject(HKManager())
}
