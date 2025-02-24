import HealthKit

// HKManager is responsible for managing HealthKit data, including checking authorization,
// requesting access, and fetching health metrics for the current day.
// The core class is HKHealthStore: https://developer.apple.com/documentation/healthkit/hkhealthstore 

@MainActor
class HKManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var healthData: [String: Double] = [
        "Steps": 0,
        "Heart Rate": 0,
        "Active Energy": 0,
        "Resting Heart Rate": 0,
        "Heart Rate Variability SDNN": 0
    ]
    
    private var allTypesToRead: Set<HKSampleType> {
        return [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        ] as Set<HKSampleType>
    }
    
    func checkAndRequestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        // After we get the authorization status for the types, then either fetch data or request authorization
        let authorizationStatuses = await withCheckedContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: [], read: allTypesToRead) { status, error in
                if let error = error {
                    print("Error checking authorization status: \(error.localizedDescription)")
                }
                continuation.resume(returning: status)
            }
        }
        
        // If we need authorization for any type, request it
        if authorizationStatuses == .shouldRequest {
            await requestAuthorization()
        } else {
            // If we have authorization for all types, just fetch data
            await fetchTodaysData()
        }
    }
    
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        let typesToShare: Set<HKSampleType> = []
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: allTypesToRead)
            print("HealthKit authorization granted")
            await fetchTodaysData()
        } catch {
            print("HealthKit authorization failed: \(error.localizedDescription)")
        }
    }
    
    // Fetch today's health data
    func fetchTodaysData() async {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Create the predicate for the query. A predicate is a filter used to specify the data to be fetched.
        let startDate = startOfDay
        let endDate = endOfDay
        
        let stepsCount = await fetchMetric(
            type: .stepCount,
            unit: HKUnit.count(),
            startDate: startDate,
            endDate: endDate
        )
        
        let heartRateValue = await fetchMetric(
            type: .heartRate,
            unit: HKUnit(from: "count/min"),
            startDate: startDate,
            endDate: endDate,
            options: .discreteAverage
        )
        
        let energyBurned = await fetchMetric(
            type: .activeEnergyBurned,
            unit: HKUnit.kilocalorie(),
            startDate: startDate,
            endDate: endDate
        )
        
        let restingHeartRateValue = await fetchMetric(
            type: .restingHeartRate,
            unit: HKUnit(from: "count/min"),
            startDate: startDate,
            endDate: endDate,
            options: .discreteAverage
        )
        
        let heartRateVariabilitySDNNValue = await fetchMetric(
            type: .heartRateVariabilitySDNN,
            unit: HKUnit(from: "ms"),
            startDate: startDate,
            endDate: endDate,
            options: .discreteAverage
        )
        
        // Update the UI with all fetched values
        await MainActor.run {
            healthData["Steps"] = stepsCount
            healthData["Heart Rate"] = heartRateValue
            healthData["Active Energy"] = energyBurned
            healthData["Resting Heart Rate"] = restingHeartRateValue
            healthData["Heart Rate Variability SDNN"] = heartRateVariabilitySDNNValue
        }
    }
    
    // Fetch a specific health metric
    private func fetchMetric(
        type identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date,
        options: HKStatisticsOptions = .cumulativeSum
    ) async -> Double {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            print("Unable to create quantity type for \(identifier)")
            return 0.0
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        // After we receive data from HealthKit, process it (e.g. calculate the average or sum if needed)
        return await withCheckedContinuation { continuation in
            let statisticsQuery = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, statistics, error in
                if let error = error {
                    print("Error fetching \(identifier): \(error.localizedDescription)")
                    continuation.resume(returning: 0.0)
                    return
                }
                
                var value: Double = 0
                if let statistics = statistics {
                    if options == .discreteAverage {
                        value = statistics.averageQuantity()?.doubleValue(for: unit) ?? 0
                    } else {
                        value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    }
                } else {
                    print("No data available for \(identifier)")
                }
                continuation.resume(returning: value)
            }
            
            healthStore.execute(statisticsQuery)
        }
    }
}