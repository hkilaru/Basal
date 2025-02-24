//
//  ContentView.swift
//  HealthKit-SwiftUI-Base
//
//  Created by Harish Kilaru on 2/24/25.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.text.clipboard")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, HealthKit!")
            Button(action: {
                // Check if the app is running in a preview
                #if DEBUG
                if !isPreview {
                    guard HKHealthStore.isHealthDataAvailable() else {
                        print("HealthKit is not available on this device")
                        return
                    }
                    healthKitManager.requestAuthorization()
                } else {
                    print("Button tapped in preview mode - no action taken.")
                }
                #endif
            }) {
                Text("Connect HealthKit")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // Helper to check if the view is in preview mode
    private var isPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

#Preview {
    ContentView()
}
