//
//  HealthMetricsSection.swift
//  Basal
//
//  Created by Harish Kilaru on 2/28/25.
//

import SwiftUI

struct HealthMetricsSection: View {
    let healthData: [String: Double]
    let timeSeriesMetrics: Set<String>
    let latestHeartRate: Double
    let latestHRV: Double
    let heartRateSamples: [(value: Double, date: Date, source: String, deviceType: String)]
    let stepsSamples: [(value: Double, date: Date, source: String, deviceType: String)]
    let hrvSamples: [(value: Double, date: Date, source: String, deviceType: String)]
    
    // Define units and icons for each metric
    private let metricInfo: [String: (unit: String, icon: String, color: Color, title: String)] = [
        "Steps": ("steps", "figure.walk", .green, "STEPS"),
        "Heart Rate": ("BPM", "heart.fill", .red, "BEATS PER MINUTE"),
        "Active Energy": ("kcal", "flame.fill", .orange, "ACTIVE ENERGY"),
        "Resting Heart Rate": ("BPM", "heart.circle.fill", .pink, "RESTING HEART RATE"),
        "Heart Rate Variability": ("ms", "waveform.path.ecg", .purple, "HEART RATE VARIABILITY"),
        "Sleep": ("", "bed.double.fill", .teal, "SLEEP")
    ]
    
    var body: some View {
        Section {
            ForEach(Array(healthData.keys.sorted().filter { $0 != "Sleep" }), id: \.self) { metric in
                if timeSeriesMetrics.contains(metric) {
                    // Navigation for timeseries metrics
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
    
    // Helper to get the display value for a metric
    private func displayValueFor(metric: String) -> Double {
        switch metric {
        case "Heart Rate":
            return latestHeartRate
        case "Heart Rate Variability":
            return latestHRV
        default:
            return healthData[metric] ?? 0
        }
    }
    
    // Helper to get samples for a metric
    private func samplesFor(metric: String) -> [(value: Double, date: Date, source: String, deviceType: String)] {
        switch metric {
        case "Heart Rate":
            return heartRateSamples
        case "Steps":
            return stepsSamples
        case "Heart Rate Variability":
            return hrvSamples
        default:
            return []
        }
    }
    
    // Helper to create consistent metric rows
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
