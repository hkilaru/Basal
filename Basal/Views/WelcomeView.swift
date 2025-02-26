import SwiftUI
import HealthKit

struct WelcomeView: View {
    @EnvironmentObject var hkManager: HKManager
    @Binding var isWelcomeSheetPresented: Bool
    
    var body: some View {
        VStack {
            // Health icons grid
            ZStack {
                // Background icons
                Group {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.teal)
                        .position(x: UIScreen.main.bounds.width * 0.35, y: UIScreen.main.bounds.height * 0.12)
                    
                    Image(systemName: "ear")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                        .position(x: UIScreen.main.bounds.width * 0.7, y: UIScreen.main.bounds.height * 0.2)
                    
                    Image(systemName: "lungs.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.cyan)
                        .position(x: UIScreen.main.bounds.width * 0.2, y: UIScreen.main.bounds.height * 0.35)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                        .position(x: UIScreen.main.bounds.width * 0.7, y: UIScreen.main.bounds.height * 0.3)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 40))
                        .foregroundStyle(.teal)
                        .position(x: UIScreen.main.bounds.width * 0.72, y: UIScreen.main.bounds.height * 0.40)
                    
                    Image(systemName: "figure.stand")
                        .font(.system(size: 40))
                        .foregroundStyle(.purple)
                        .position(x: UIScreen.main.bounds.width * 0.7, y: UIScreen.main.bounds.height * 0.1)
                    
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 40))
                        .foregroundStyle(.yellow)
                        .position(x: UIScreen.main.bounds.width * 0.2, y: UIScreen.main.bounds.height * 0.2)
                    
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.pink)
                        .position(x: UIScreen.main.bounds.width * 0.5, y: UIScreen.main.bounds.height * 0.45)
                    
                    Image(systemName: "pill.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                        .position(x: UIScreen.main.bounds.width * 0.5, y: UIScreen.main.bounds.height * 0.36)
                }
                
                // Center heart icon
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white)
                        .shadow(radius: 5)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "heart.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.pink)
                }
            }
            .frame(height: UIScreen.main.bounds.height * 0.5)
            
            
            // Bottom text and button
            VStack(spacing: 20) {
                Text("Welcome to Basal")
                    .font(.largeTitle)
                    .bold()
                
                Text("It's a simple foundation for fetching HealthKit data. You can modify data sources in `HKManager`.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button {
                    Task {
                        await hkManager.requestAuthorization()
                        isWelcomeSheetPresented = false
                    }
                } label: {
                    Text("Connect")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
        }
        .padding()
    }
}

#Preview {
    WelcomeView(isWelcomeSheetPresented: .constant(true))
        .environmentObject(HKManager())
} 
