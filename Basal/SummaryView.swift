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
        "Body Mass": ("kg", "scalemass.fill", .green, "BODY MASS")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(hkManager.healthData.keys.sorted()), id: \.self) { metric in
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
}

#Preview {
    SummaryView()
        .environmentObject(HKManager())
}
