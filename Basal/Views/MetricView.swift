import SwiftUI
import HealthKit

// MetricView displays a list of samples for a given metric and the source of
// each sample.
struct MetricView: View {
    let title: String
    let samples: [(value: Double, date: Date, source: String, deviceType: String)]
    let unit: String
    let icon: String
    let color: Color
    let isSleepData: Bool
    
    // Initialize with default values
    init(
        title: String,
        samples: [(value: Double, date: Date, source: String, deviceType: String)],
        unit: String,
        icon: String,
        color: Color,
        isSleepData: Bool = false
    ) {
        self.title = title
        self.samples = samples
        self.unit = unit
        self.icon = icon
        self.color = color
        self.isSleepData = isSleepData
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            if samples.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 50))
                        .foregroundColor(color.opacity(0.5))
                    
                    Text("No \(title.lowercased()) data recorded today")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.secondarySystemGroupedBackground))
            } else {
                // List of samples
                ScrollView {
                    // Header
                    Text(title)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .background(Color(UIColor.systemGroupedBackground))

                    LazyVStack(spacing: 0) {
                        ForEach(samples.indices, id: \.self) { index in
                            VStack(spacing: 0) {
                                HStack {
                                    // Device icon based on deviceType
                                    Image(systemName: iconForDeviceType(samples[index].deviceType))
                                        .foregroundColor(colorForDeviceType(samples[index].deviceType))
                                        .font(.title3)
                                        .frame(width: 20)
                                    
                                    // Value
                                    if isSleepData {
                                        Text("\(Int(samples[index].value))min")
                                            .font(.body)
                                            .fontWeight(.medium)
                                    } else {
                                        Text(formatValue(samples[index].value))
                                            .font(.body)
                                            .fontWeight(.medium)
                                    }
                                    
                                    Spacer()
                                    
                                    // Date
                                    if isSleepData {
                                        // For sleep data, show time range
                                        let endDate = samples[index].date.addingTimeInterval(TimeInterval(Int(samples[index].value) * 60))
                                        Text("\(timeFormatter.string(from: samples[index].date)) - \(timeFormatter.string(from: endDate))")
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(dateFormatter.string(from: samples[index].date))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                            }
                            
                            if index < samples.count - 1 {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .navigationTitle("All Recorded Data")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Format value based on the type of data
    private func formatValue(_ value: Double) -> String {
        // For steps, we want to show the full number without decimal places
        if title.contains("STEPS") {
            return "\(Int(value))"
        }
        
        // For heart rate, we want to show whole numbers
        if title.contains("BEATS PER MINUTE") {
            return "\(Int(value))"
        }
        
        // For HRV, we want to show one decimal place
        if title.contains("HEART RATE VARIABILITY") {
            return String(format: "%.1f", value)
        }
        
        // Default formatting
        return "\(Int(value))"
    }
    
    // Get the appropriate icon for the device type
    private func iconForDeviceType(_ deviceType: String) -> String {
        switch deviceType {
        case "Apple Watch":
            return "applewatch"
        case "iPhone":
            return "iphone"
        default:
            return "app.fill"
        }
    }
    
    // Get the appropriate color for the device type
    private func colorForDeviceType(_ deviceType: String) -> Color {
        switch deviceType {
        case "Apple Watch":
            return .blue
        case "iPhone":
            return .green
        default:
            return .gray
        }
    }
}

#Preview {
    NavigationView {
        MetricView(
            title: "STEPS",
            samples: [
                (value: 1200, date: Date().addingTimeInterval(-3600), source: "iPhone", deviceType: "iPhone"),
                (value: 800, date: Date().addingTimeInterval(-7200), source: "Apple Watch", deviceType: "Apple Watch"),
                (value: 500, date: Date().addingTimeInterval(-10800), source: "Fitbit", deviceType: "Fitbit")
            ],
            unit: "steps",
            icon: "figure.walk",
            color: .green
        )
    }
} 
