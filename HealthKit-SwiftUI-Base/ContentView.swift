//
//  ContentView.swift
//  HealthKit-SwiftUI-Base
//
//  Created by Harish Kilaru on 2/24/25.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @EnvironmentObject var hkManager: HKManager
    @State private var showWelcomeSheet = false
    
    // Define units and icons for each metric
    private let metricInfo: [String: (unit: String, icon: String, color: Color)] = [
        "Steps": ("steps", "figure.walk", .green),
        "Heart Rate": ("BPM", "heart.fill", .red),
        "Active Energy": ("kcal", "flame.fill", .orange),
        "Resting Heart Rate": ("BPM", "heart.circle.fill", .pink),
        "Heart Rate Variability": ("ms", "waveform.path.ecg", .purple)
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(hkManager.healthData.keys.sorted()), id: \.self) { metric in
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
                            Text("\(hkManager.healthData[metric] ?? 0, specifier: "%.0f")")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(metricInfo[metric]?.unit ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
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
}

#Preview {
    ContentView()
        .environmentObject(HKManager())
}
