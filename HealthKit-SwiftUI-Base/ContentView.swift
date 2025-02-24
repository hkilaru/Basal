//
//  ContentView.swift
//  HealthKit-SwiftUI-Base
//
//  Created by Harish Kilaru on 2/24/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.text.clipboard")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, HealthKit!")
            Button(action: {
                print("Button pressed")
            }) {
                Text("Connect HealthKit")
            }.buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
