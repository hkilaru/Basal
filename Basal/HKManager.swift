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
        "Heart Rate Variability": 0,
        "Height": 0,
        "Body Mass": 0
    ]
    
    // Store the latest values
    @Published var latestHeartRate: Double = 0
    @Published var latestHRV: Double = 0
    
    // Store individual samples
    @Published var heartRateSamples: [(value: Double, date: Date, source: String, deviceType: String)] = []
    @Published var stepsSamples: [(value: Double, date: Date, source: String, deviceType: String)] = []
    @Published var hrvSamples: [(value: Double, date: Date, source: String, deviceType: String)] = []
    
    // Define which metrics have time-series data
    let timeSeriesMetrics = ["Heart Rate", "Steps", "Heart Rate Variability"]
    
    private var allTypesToRead: Set<HKSampleType> {
        return [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            
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
        
        // Create the predicate for the query
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
        
        // Fetch individual samples for timeseries data
        await fetchHeartRateSamples(startDate: startDate, endDate: endDate)
        await fetchStepsSamples(startDate: startDate, endDate: endDate)
        await fetchHRVSamples(startDate: startDate, endDate: endDate)
        
        // Update the UI with all fetched values
        await MainActor.run {
            healthData["Steps"] = stepsCount
            healthData["Heart Rate"] = heartRateValue
            healthData["Active Energy"] = energyBurned
            healthData["Resting Heart Rate"] = restingHeartRateValue
            healthData["Heart Rate Variability"] = heartRateVariabilitySDNNValue
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
    
    // Fetch individual heart rate samples
    func fetchHeartRateSamples(startDate: Date, endDate: Date) async {
        let samples = await fetchSamples(
            for: .heartRate,
            unit: HKUnit(from: "count/min"),
            startDate: startDate,
            endDate: endDate
        )
        
        await MainActor.run {
            self.heartRateSamples = samples
            if let firstSample = samples.first {
                self.latestHeartRate = firstSample.value
            }
        }
    }
    
    // Fetch individual steps samples
    func fetchStepsSamples(startDate: Date, endDate: Date) async {
        let samples = await fetchSamples(
            for: .stepCount,
            unit: HKUnit.count(),
            startDate: startDate,
            endDate: endDate
        )
        
        await MainActor.run {
            self.stepsSamples = samples
        }
    }
    
    // Fetch individual HRV samples
    func fetchHRVSamples(startDate: Date, endDate: Date) async {
        let samples = await fetchSamples(
            for: .heartRateVariabilitySDNN,
            unit: HKUnit(from: "ms"),
            startDate: startDate,
            endDate: endDate
        )
        
        await MainActor.run {
            self.hrvSamples = samples
            if let firstSample = samples.first {
                self.latestHRV = firstSample.value
            }
        }
    }
    
    // Generic function to fetch samples for any quantity type
    private func fetchSamples(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date
    ) async -> [(value: Double, date: Date, source: String, deviceType: String)] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            print("Unable to create quantity type for \(identifier)")
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        // Sort by date, most recent first
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("Error fetching \(identifier) samples: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }
                
                var resultSamples: [(value: Double, date: Date, source: String, deviceType: String)] = []
                
                if let samples = samples as? [HKQuantitySample], !samples.isEmpty {
                    for sample in samples {
                        let value = sample.quantity.doubleValue(for: unit)
                        
                        // Get source information
                        let sourceInfo = self.determineSourceInfo(from: sample)
                        
                        resultSamples.append((
                            value: value, 
                            date: sample.endDate, 
                            source: sourceInfo.name,
                            deviceType: sourceInfo.type
                        ))
                    }
                }
                
                continuation.resume(returning: resultSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    // Helper method to determine the source name and type from a sample
    // so we can display the correct device source
    private nonisolated func determineSourceInfo(from sample: HKSample) -> (name: String, type: String) {
        let sourceName = sample.sourceRevision.source.name
        var deviceType = "Unknown"
        
        if let device = sample.device {
            if let model = device.model {
                if model.contains("Watch") {
                    deviceType = "Apple Watch"
                } else if model.contains("iPhone") {
                    deviceType = "iPhone"
                } else {
                    deviceType = model
                }
            }
        } else {
            // Fallback to source bundle identifier if no device info
            let bundleID = sample.sourceRevision.source.bundleIdentifier
            
            if bundleID.contains("apple.health") {
                deviceType = "iPhone"
            } else if (bundleID.contains("workout") || bundleID.contains("activity")) {
                deviceType = "Apple Watch"
            }
        }
        
        return (name: sourceName, type: deviceType)
    }
    
    // Also mark the other helper method as nonisolated
    private nonisolated func determineSourceName(from sample: HKSample) -> String {
        if let device = sample.device {
            if let model = device.model, model.contains("Watch") {
                return "Apple Watch"
            } else if let model = device.model, model.contains("iPhone") {
                return "iPhone"
            }
        }
        
        let bundleID = sample.sourceRevision.source.bundleIdentifier
        let sourceName = sample.sourceRevision.source.name
        
        let isIPhoneSource = (bundleID.contains("apple.health")) ||
                             sourceName == "Health" || 
                             sourceName.contains("iPhone")
        
        let isWatchSource = (bundleID.contains("workout") || bundleID.contains("activity")) ||
                            sourceName.contains("Watch")
        
        if isIPhoneSource {
            return "iPhone"
        } else if isWatchSource {
            return "Apple Watch"
        }
        
        return sourceName
    }
}
