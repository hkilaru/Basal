//
//  HealthKit_SwiftUI_BaseApp.swift
//  HealthKit-SwiftUI-Base
//
//  Created by Harish Kilaru on 2/24/25.
//

import SwiftUI

@main
struct HealthKit_SwiftUI_BaseApp: App {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var isWelcomeSheetPresented = false
    @StateObject private var hkManager = HKManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(hkManager)
                .sheet(isPresented: $isWelcomeSheetPresented) {
                    WelcomeView(isWelcomeSheetPresented: $isWelcomeSheetPresented)
                        .environmentObject(hkManager)
                }
                .onAppear {
                    // Only show welcome sheet if user hasn't seen it before
                    if !hasSeenWelcome {
                        isWelcomeSheetPresented = true
                    } else {
                        // If user has already seen welcome, check permissions and fetch data
                        Task {
                            await hkManager.checkAndRequestAuthorization()
                        }
                    }
                }
                .onChange(of: isWelcomeSheetPresented) { _, newValue in
                    if !newValue {
                        hasSeenWelcome = true
                    }
                }
        }
    }
}
