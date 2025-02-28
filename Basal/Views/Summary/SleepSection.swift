//
//  SleepSection.swift
//  Basal
//
//  Created by Harish Kilaru on 2/28/25.
//

import SwiftUI

struct SleepSection: View {
    let sleepData: SleepData
    
    var body: some View {
        Section {
            if sleepData.hasSleepData {
                NavigationLink {
                    SleepSummaryView(sleepData: sleepData)
                } label: {
                    sleepRow()
                }
            } else {
                sleepRow()
            }
        } header: {
            Text("Sleep")
        }
    }
    
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
                
                if sleepData.hasSleepData {
                    Text(sleepData.formattedDateRange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Value
            if sleepData.hasSleepData {
                Text(sleepData.formattedTotalSleepTime)
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
} 