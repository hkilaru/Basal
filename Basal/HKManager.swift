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
        "Body Mass": 0,
        "Sleep": 0
    ]
    
    // Store the latest values
    @Published var latestHeartRate: Double = 0
    @Published var latestHRV: Double = 0
    
    // Store individual samples
    @Published var heartRateSamples: [(value: Double, date: Date, source: String, deviceType: String)] = []
    @Published var stepsSamples: [(value: Double, date: Date, source: String, deviceType: String)] = []
    @Published var hrvSamples: [(value: Double, date: Date, source: String, deviceType: String)] = []
    
    // Sleep data
    @Published var sleepData: SleepData = SleepData()
    
    // Workout data
    @Published var workoutCollection: WorkoutCollection = WorkoutCollection()
    
    // Define which metrics have time-series data
    let timeSeriesMetrics = ["Heart Rate", "Steps", "Heart Rate Variability", "Sleep"]
    
    private var allTypesToRead: Set<HKSampleType> {
        return [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.workoutType()
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
        
        // Fetch sleep data for last night
        await fetchLastNightSleepData()
        
        // Fetch workouts
        await fetchWorkouts()
        
        // Update the UI with all fetched values
        await MainActor.run {
            healthData["Steps"] = stepsCount
            healthData["Heart Rate"] = heartRateValue
            healthData["Active Energy"] = energyBurned
            healthData["Resting Heart Rate"] = restingHeartRateValue
            healthData["Heart Rate Variability"] = heartRateVariabilitySDNNValue
            
            // Update sleep duration in minutes
            healthData["Sleep"] = Double(sleepData.totalSleepDuration)
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
            // Fallback to source name and bundle identifier if no device info
            let bundleID = sample.sourceRevision.source.bundleIdentifier
            
            // Check if the source name contains "Watch" first
            if sourceName.contains("Watch") {
                deviceType = "Apple Watch"
            }
            // Then check bundle ID if still unknown
            else if bundleID.contains("apple.health") {
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
    
    // MARK: - Sleep Data Methods
    
    /// Fetches sleep data for the previous night
    func fetchLastNightSleepData() async {
        let calendar = Calendar.current
        let now = Date()
        
        // Get yesterday's date and today's date
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let yesterdayStart = calendar.startOfDay(for: yesterday)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        
        // Create a predicate for the query
        let predicate = HKQuery.predicateForSamples(
            withStart: yesterdayStart,
            end: todayEnd,
            options: .strictStartDate
        )
        
        // Get the sleep analysis category type
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("Sleep Analysis is not available in HealthKit")
            return
        }
        
        // Sort by start date, most recent first
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        // Create a new sleep data object
        var newSleepData = SleepData()
        
        // Fetch the sleep samples
        let samples = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = samples else {
                    continuation.resume(returning: [])
                    return
                }
                
                continuation.resume(returning: samples)
            }
            
            healthStore.execute(query)
        }
        
        guard let samples = samples else {
            print("Failed to fetch sleep samples")
            return
        }
        
        // Process the sleep samples
        processSleepSamples(samples, into: &newSleepData)
        
        // Update the sleep data on the main actor
        await MainActor.run {
            self.sleepData = newSleepData
        }
    }
    
    /// Process sleep samples into a structured SleepData object
    private nonisolated func processSleepSamples(_ samples: [HKSample], into sleepData: inout SleepData) {
        // Filter for Apple Watch and Health app sources
        let filteredSamples = samples.filter { sample in
            let source = sample.sourceRevision.source.bundleIdentifier
            return source.contains("com.apple.health") || 
                   source.contains("com.apple.HealthKit") ||
                   source.contains("com.apple.healthkit") ||
                   source.contains("com.apple.workout") ||
                   source.contains("com.apple.sleep")
        }
        
        guard !filteredSamples.isEmpty else {
            print("No valid sleep samples found")
            return
        }
        
        // Find the sleep session with the longest duration
        var sleepSessions: [SleepSession] = []
        
        for sample in filteredSamples {
            guard let categorySample = sample as? HKCategorySample else { continue }
            
            let value = categorySample.value
            let startDate = categorySample.startDate
            let endDate = categorySample.endDate
            let duration = endDate.timeIntervalSince(startDate)
            let sourceInfo = determineSourceInfo(from: sample)
            
            // Map HKCategoryValueSleepAnalysis to our SleepStage enum
            let stage: SleepStage
            
            if #available(iOS 16.0, *) {
                switch value {
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    stage = .inBed
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    stage = .awake
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    stage = .unspecified
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    stage = .rem
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    stage = .core
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    stage = .deep
                default:
                    stage = .unspecified
                }
            } else {
                // For iOS 15 and earlier
                switch value {
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    stage = .inBed
                case HKCategoryValueSleepAnalysis.asleep.rawValue:
                    stage = .unspecified
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    stage = .awake
                default:
                    stage = .unspecified
                }
            }
            
            // Create a sleep interval
            let interval = SleepInterval(
                stage: stage,
                startDate: startDate,
                endDate: endDate,
                duration: Int(duration),
                source: sourceInfo.name,
                deviceType: sourceInfo.type
            )
            
            // Check if this interval belongs to an existing session or is a new session
            if let lastSessionIndex = sleepSessions.indices.last,
               let lastIntervalEndDate = sleepSessions[lastSessionIndex].intervals.last?.endDate,
               startDate.timeIntervalSince(lastIntervalEndDate) < 3600 { // Less than 1 hour gap
                // Add to existing session
                sleepSessions[lastSessionIndex].intervals.append(interval)
            } else {
                // Create a new session
                let session = SleepSession(intervals: [interval])
                sleepSessions.append(session)
            }
        }
        
        // Find the session with the most sleep data
        if let mainSession = sleepSessions.max(by: { $0.totalDuration < $1.totalDuration }) {
            // Sort intervals by start date
            let sortedIntervals = mainSession.intervals.sorted { $0.startDate < $1.startDate }
            
            // Group intervals by stage
            var awakeIntervals: [SleepInterval] = []
            var remIntervals: [SleepInterval] = []
            var coreIntervals: [SleepInterval] = []
            var deepIntervals: [SleepInterval] = []
            
            for interval in sortedIntervals {
                switch interval.stage {
                case .awake:
                    awakeIntervals.append(interval)
                case .rem:
                    remIntervals.append(interval)
                case .core:
                    coreIntervals.append(interval)
                case .deep:
                    deepIntervals.append(interval)
                case .inBed, .unspecified:
                    // Skip these for now
                    break
                }
            }
            
            // Calculate total sleep time (excluding awake time)
            let totalSleepTime = remIntervals.reduce(0) { $0 + $1.duration } +
                                coreIntervals.reduce(0) { $0 + $1.duration } +
                                deepIntervals.reduce(0) { $0 + $1.duration }
            
            // Set the sleep data
            sleepData.date = sortedIntervals.first?.startDate ?? Date()
            sleepData.awakeIntervals = awakeIntervals
            sleepData.remIntervals = remIntervals
            sleepData.coreIntervals = coreIntervals
            sleepData.deepIntervals = deepIntervals
            sleepData.totalSleepDuration = totalSleepTime
            
            // Find the overall start and end time of the sleep session
            if let firstInterval = sortedIntervals.first, let lastInterval = sortedIntervals.last {
                sleepData.startTime = firstInterval.startDate
                sleepData.endTime = lastInterval.endDate
            }
        }
    }
    
    // MARK: - Workout Methods
    
    func fetchWorkouts() async {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Create the predicate for the query
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        // Sort by date, most recent first
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(
                    sampleType: HKObjectType.workoutType(),
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let samples = samples else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    continuation.resume(returning: samples)
                }
                
                healthStore.execute(query)
            }
            
            // Process the workout samples
            var workouts: [WorkoutData] = []
            
            for sample in samples {
                if let workout = sample as? HKWorkout {
                    // Get source information
                    let sourceInfo = determineSourceInfo(from: workout)
                    
                    // Create a workout data object
                    var workoutData = WorkoutData(
                        workoutType: workout.workoutActivityType,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        duration: workout.duration,
                        totalEnergyBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                        totalDistance: workout.totalDistance?.doubleValue(for: .meter()),
                        source: sourceInfo.name,
                        deviceType: sourceInfo.type,
                        workoutEvents: workout.workoutEvents,
                        metadata: workout.metadata
                    )
                    
                    // Fetch additional metrics for this workout
                    await fetchAdditionalMetrics(for: workout, into: &workoutData)
                    
                    workouts.append(workoutData)
                }
            }
            
            // Update the workout collection on the main actor
            await MainActor.run {
                self.workoutCollection.workouts = workouts
            }
        } catch {
            print("Error fetching workouts: \(error.localizedDescription)")
        }
    }
    
    // Fetch additional metrics for a workout
    private func fetchAdditionalMetrics(for workout: HKWorkout, into workoutData: inout WorkoutData) async {
        // Fetch heart rate data
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            let heartRateValue = await fetchWorkoutMetric(
                for: workout,
                quantityType: heartRateType,
                unit: HKUnit(from: "count/min"),
                options: .discreteAverage
            )
            workoutData.averageHeartRate = heartRateValue
        }
        
        // Fetch active energy burned
        if let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            let activeEnergyValue = await fetchWorkoutMetric(
                for: workout,
                quantityType: activeEnergyType,
                unit: HKUnit.kilocalorie(),
                options: .cumulativeSum
            )
            workoutData.activeEnergyBurned = activeEnergyValue
        }
        
        // For elevation gain, we'll use flightsClimbed as a proxy
        if let flightsClimbedType = HKObjectType.quantityType(forIdentifier: .flightsClimbed) {
            let flightsValue = await fetchWorkoutMetric(
                for: workout,
                quantityType: flightsClimbedType,
                unit: HKUnit.count(),
                options: .cumulativeSum
            )
            // Approximate: 1 flight ≈ 10 feet
            workoutData.elevationGain = flightsValue * 10
        }
        
        // Fetch power data (for cycling, strength training)
        if let powerType = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned) {
            let powerValue = await fetchWorkoutMetric(
                for: workout,
                quantityType: powerType,
                unit: HKUnit.watt(),
                options: .cumulativeSum
            )
            workoutData.averagePower = powerValue
        }
        
        // For cadence, we'll calculate it from speed and stride length
        // First, get the running speed
        if let speedType = HKObjectType.quantityType(forIdentifier: .runningSpeed) {
            let speedValue = await fetchWorkoutMetric(
                for: workout,
                quantityType: speedType,
                unit: HKUnit.meter().unitDivided(by: HKUnit.second()),
                options: .discreteAverage
            )
            
            if speedValue > 0 {
                workoutData.averagePace = 1.0 / speedValue
                
                // Estimate cadence based on speed
                // For running, typical stride length is about 0.7-1.0 meters
                // Cadence = Speed / Stride Length
                // We'll use an average stride length of 0.85 meters
                let estimatedStrideLength = 0.85 // meters
                let estimatedCadence = (speedValue / estimatedStrideLength) * 60 // steps per minute
                workoutData.averageCadence = estimatedCadence
            }
        } else {
            // If running speed isn't available, try to get stride length and steps directly
            // This is a fallback and may not be available for all workouts
            if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
                let stepsValue = await fetchWorkoutMetric(
                    for: workout,
                    quantityType: stepsType,
                    unit: HKUnit.count(),
                    options: .cumulativeSum
                )
                
                if stepsValue > 0 && workout.duration > 0 {
                    // Calculate cadence as steps per minute
                    let cadence = (stepsValue / workout.duration) * 60
                    workoutData.averageCadence = cadence
                }
            }
        }
    }
    
    // Fetch a specific metric for a workout
    private func fetchWorkoutMetric(
        for workout: HKWorkout,
        quantityType: HKQuantityType,
        unit: HKUnit,
        options: HKStatisticsOptions
    ) async -> Double {
        // Create a predicate to get samples that belong to this workout
        let predicate = HKQuery.predicateForObjects(from: workout)
        
        return await withCheckedContinuation { continuation in
            let statisticsQuery = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, statistics, error in
                if let error = error {
                    print("Error fetching workout metric: \(error.localizedDescription)")
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
                }
                continuation.resume(returning: value)
            }
            
            healthStore.execute(statisticsQuery)
        }
    }
}
