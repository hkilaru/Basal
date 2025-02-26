import SwiftUI

// SleepSummaryView displays the sleep data for the last night
// organized by sleep stage.

struct SleepSummaryView: View {
    let sleepData: SleepData
    
    var body: some View {
        List {
            ForEach(sleepData.sleepStageSummary.indices, id: \.self) { index in
                let stageData = sleepData.sleepStageSummary[index]
                let stageMetrics = sleepData.sleepStageMetrics[index]
                
                if !stageMetrics.samples.isEmpty {
                    NavigationLink {
                        MetricView(
                            title: "\(stageData.title.uppercased()) INTERVALS",
                            samples: stageMetrics.samples,
                            unit: "min",
                            icon: stageData.icon,
                            color: stageData.color,
                            isSleepData: true
                        )
                    } label: {
                        sleepStageRow(stageData)
                    }
                }
            }
        }
        .navigationTitle("All Recorded Data")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sleepStageRow(_ stageData: (title: String, count: Int, duration: Int, icon: String, color: Color)) -> some View {
        HStack(spacing: 12) {
            
            // Stage name
            Text(stageData.title)
                .font(.body)
            
            Spacer()
            
            // Value with unit
            VStack(alignment: .trailing) {
                // Format duration
                let hours = stageData.duration / 3600
                let minutes = (stageData.duration % 3600) / 60
                
                if hours > 0 {
                    Text("\(hours)hr \(minutes)min")
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
                    Text("\(minutes)min")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                    
                let intervalCount = stageData.count
                Text("(\(intervalCount) \(intervalCount == 1 ? "interval" : "intervals"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            }
        }.padding(.vertical, 2)
        .padding(.horizontal, 4)
    }
}

#Preview {
    NavigationView {
        SleepSummaryView(sleepData: SleepData(
            awakeIntervals: [
                SleepInterval(stage: .awake, startDate: Date(), endDate: Date().addingTimeInterval(600), duration: 600, source: "Apple Watch", deviceType: "Apple Watch")
            ],
            remIntervals: [
                SleepInterval(stage: .rem, startDate: Date(), endDate: Date().addingTimeInterval(3600), duration: 3600, source: "Apple Watch", deviceType: "Apple Watch")
            ],
            coreIntervals: [
                SleepInterval(stage: .core, startDate: Date(), endDate: Date().addingTimeInterval(7200), duration: 7200, source: "Apple Watch", deviceType: "Apple Watch")
            ],
            deepIntervals: [
                SleepInterval(stage: .deep, startDate: Date(), endDate: Date().addingTimeInterval(3600), duration: 3600, source: "Apple Watch", deviceType: "Apple Watch")
            ],
            totalSleepDuration: 14400
        ))
    }
} 
