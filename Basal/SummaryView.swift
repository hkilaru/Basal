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
    @State private var selectedDate = Date()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    DateCarouselView(
                        selectedDate: $selectedDate,
                        onDateSelected: { date in
                            Task {
                                await hkManager.fetchHealthDataIfNeeded(for: date)
                            }
                        }
                    )
                    .padding(.top, 8)
                    
                    List {
                        SleepSection(sleepData: hkManager.sleepData)
                        
                        WorkoutsSection(workouts: hkManager.workoutCollection.workoutsForSelectedDate)
                        
                        HealthMetricsSection(
                            healthData: hkManager.healthData,
                            timeSeriesMetrics: Set(hkManager.timeSeriesMetrics),
                            latestHeartRate: hkManager.latestHeartRate,
                            latestHRV: hkManager.latestHRV,
                            heartRateSamples: hkManager.heartRateSamples,
                            stepsSamples: hkManager.stepsSamples,
                            hrvSamples: hkManager.hrvSamples
                        )
                    }
                    .listStyle(InsetGroupedListStyle())
                }
                
                // Loading overlay
                if let loadingDate = hkManager.loadingDate,
                   Calendar.current.isDate(loadingDate, inSameDayAs: selectedDate) {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
            }
            .navigationTitle(formattedNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await hkManager.fetchHealthDataIfNeeded(for: selectedDate)
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
        }
        .task {
            // Initial data fetch
            await hkManager.fetchHealthDataIfNeeded(for: selectedDate)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Fetch last 30 days of data when app becomes active
            if newPhase == .active {
                Task {
                    await hkManager.fetchLast30DaysData()
                }
            }
        }
        .sheet(isPresented: $showWelcomeSheet) {
            WelcomeView(isWelcomeSheetPresented: $showWelcomeSheet)
        }
    }
    
    // Format the navigation title based on selected date
    private var formattedNavigationTitle: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(selectedDate) {
            // Format: "Today, Feb 28, 2025"
            formatter.dateFormat = "MMM d, yyyy"
            return "Today, \(formatter.string(from: selectedDate))"
        } else {
            // Format: "Monday, Feb 24, 2025"
            formatter.dateFormat = "EEEE, MMM d, yyyy"
            return formatter.string(from: selectedDate)
        }
    }
}

#Preview {
    SummaryView()
        .environmentObject(HKManager())
}
