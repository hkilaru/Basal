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
        "Sleep": 0
    ]
    
    // Store the latest values
    @Published var latestHeartRate: Double = 0
    @Published var latestHRV: Double = 0
    
    // Loading states
    @Published private(set) var loadingDate: Date? = nil
    @Published private(set) var isBackgroundLoading = false
    
    // Store individual samples
    @Published var heartRateSamples: [(value: Double, date: Date, source: String, deviceType: String)] = []
    @Published var stepsSamples: [(value: Double, date: Date, source: String, deviceType: String)] = []
    @Published var hrvSamples: [(value: Double, date: Date, source: String, deviceType: String)] = []
    
    // Sleep data
    @Published var sleepData: SleepData = SleepData()
    
    // Workout data
    @Published var workoutCollection: WorkoutCollection = WorkoutCollection()
    
    // Cache for background-fetched data
    private var cachedHealthData: [Date: [String: Double]] = [:]
    private var cachedSleepData: [Date: SleepData] = [:]
    private var cachedWorkouts: [WorkoutData] = []
    private var cachedSamples: [Date: (
        heartRate: [(value: Double, date: Date, source: String, deviceType: String)],
        steps: [(value: Double, date: Date, source: String, deviceType: String)],
        hrv: [(value: Double, date: Date, source: String, deviceType: String)]
    )] = [:]
    
    // Define which metrics have time-series data
    let timeSeriesMetrics = ["Heart Rate", "Steps", "Heart Rate Variability", "Sleep"]
    
    // Add this property to the HKManager class
    @Published private(set) var fetchedDates: [Date: Bool] = [:]
    
    private var allTypesToRead: Set<HKSampleType> {
        return [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
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
        await fetchHealthData(for: Date())
    }
    
    // Fetch health data for a specific date
    func fetchHealthData(for date: Date, updateSelectedDate: Bool = true, inBackground: Bool = false) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Use these dates for all subsequent fetches
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
        let hrSamples = await fetchHeartRateSamples(startDate: startDate, endDate: endDate)
        let stepsSamples = await fetchStepsSamples(startDate: startDate, endDate: endDate)
        let hrvSamples = await fetchHRVSamples(startDate: startDate, endDate: endDate)
        
        // Fetch sleep data for the selected night
        let sleepData = await fetchSleepDataForDate(date)
        
        // Fetch workouts for the selected date
        let workouts = await fetchWorkoutsForDate(date)
        
        await MainActor.run {
            let newHealthData: [String: Double] = [
                "Steps": stepsCount,
                "Heart Rate": heartRateValue,
                "Active Energy": energyBurned,
                "Resting Heart Rate": restingHeartRateValue,
                "Heart Rate Variability": heartRateVariabilitySDNNValue,
                "Sleep": Double(sleepData.totalSleepDuration)
            ]
            
            if inBackground {
                // Store in cache
                self.cachedHealthData[startOfDay] = newHealthData
                self.cachedSleepData[startOfDay] = sleepData
                self.cachedWorkouts.append(contentsOf: workouts)
                self.cachedSamples[startOfDay] = (
                    heartRate: hrSamples,
                    steps: stepsSamples,
                    hrv: hrvSamples
                )
            } else {
                // Update displayed data
                self.healthData = newHealthData
                self.sleepData = sleepData
                
                // Update samples
                self.heartRateSamples = hrSamples
                self.stepsSamples = stepsSamples
                self.hrvSamples = hrvSamples
                
                // Update latest values if available
                if let firstHR = hrSamples.first {
                    self.latestHeartRate = firstHR.value
                }
                if let firstHRV = hrvSamples.first {
                    self.latestHRV = firstHRV.value
                }
                
                // Only update workouts if not in background
                if updateSelectedDate {
                    self.workoutCollection.selectedDate = date
                }
                self.workoutCollection.workouts = workouts
            }
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
    func fetchHeartRateSamples(startDate: Date, endDate: Date) async -> [(value: Double, date: Date, source: String, deviceType: String)] {
        let samples = await fetchSamples(
            for: .heartRate,
            unit: HKUnit(from: "count/min"),
            startDate: startDate,
            endDate: endDate
        )
        
        return samples
    }
    
    // Fetch individual steps samples
    func fetchStepsSamples(startDate: Date, endDate: Date) async -> [(value: Double, date: Date, source: String, deviceType: String)] {
        let samples = await fetchSamples(
            for: .stepCount,
            unit: HKUnit.count(),
            startDate: startDate,
            endDate: endDate
        )
        
        return samples
    }
    
    // Fetch individual HRV samples
    func fetchHRVSamples(startDate: Date, endDate: Date) async -> [(value: Double, date: Date, source: String, deviceType: String)] {
        let samples = await fetchSamples(
            for: .heartRateVariabilitySDNN,
            unit: HKUnit(from: "ms"),
            startDate: startDate,
            endDate: endDate
        )
        
        return samples
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
    
    // Sleep Data Methods
    
    /// Fetches sleep data for the previous night
    func fetchSleepDataForDate(_ date: Date) async -> SleepData {
        let calendar = Calendar.current
        
        // For sleep, we want the night that starts on the previous day
        // and ends on the selected date
        let previousDay = calendar.date(byAdding: .day, value: -1, to: date)!
        let previousDayStart = calendar.startOfDay(for: previousDay)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        
        // Create a predicate for the query
        let predicate = HKQuery.predicateForSamples(
            withStart: previousDayStart,
            end: dayEnd,
            options: .strictStartDate
        )
        
        // Get the sleep analysis category type
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("Sleep Analysis is not available in HealthKit")
            return SleepData()
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
            return SleepData()
        }
        
        // Process the sleep samples
        processSleepSamples(samples, into: &newSleepData)
        
        return newSleepData
    }
    
    /// Process sleep samples into a structured SleepData object
    private nonisolated func processSleepSamples(_ samples: [HKSample], into sleepData: inout SleepData) {
        
        // Group samples by sleep session using a more natural approach
        let sortedSamples = samples.sorted { $0.startDate < $1.startDate }
        var sleepSessions: [[HKSample]] = []
        var currentSession: [HKSample] = []
        
        // Start a new sleep session if someone is awake for more than an hour,
        // it's likely a different sleep session
        let sessionGapThreshold: TimeInterval = 60 * 60
        
        for sample in sortedSamples {
            if let lastSample = currentSession.last {
                // Calculate the gap between this sample and the last one
                let gap = sample.startDate.timeIntervalSince(lastSample.endDate)
                
                // If there's a significant gap, start a new session
                if gap > sessionGapThreshold {
                    sleepSessions.append(currentSession)
                    currentSession = [sample]
                } else {
                    // Otherwise, add to current session
                    currentSession.append(sample)
                }
            } else {
                // First sample
                currentSession.append(sample)
            }
        }
        
        // Add the last session if not empty
        if !currentSession.isEmpty {
            sleepSessions.append(currentSession)
        }
                
        // Find the most recent session that ends within our date range
        if let mostRecentSession = sleepSessions.last {            
            // Process only the most recent session
            var awakeIntervals: [SleepInterval] = []
            var remIntervals: [SleepInterval] = []
            var coreIntervals: [SleepInterval] = []
            var deepIntervals: [SleepInterval] = []
            
            for sample in mostRecentSession {
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
                        continue // Skip unknown stages
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
                        continue // Skip unknown stages
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
                
                // Add to appropriate array
                switch stage {
                case .awake:
                    awakeIntervals.append(interval)
                case .rem:
                    remIntervals.append(interval)
                case .core:
                    coreIntervals.append(interval)
                case .deep:
                    deepIntervals.append(interval)
                case .inBed, .unspecified:
                    break // Skip these stages
                }
            }
            
            // Update sleep data
            sleepData.awakeIntervals = awakeIntervals
            sleepData.remIntervals = remIntervals
            sleepData.coreIntervals = coreIntervals
            sleepData.deepIntervals = deepIntervals
            
            // Calculate total sleep duration (excluding awake time)
            let totalSleepTime = remIntervals.reduce(0) { $0 + $1.duration } +
                                 coreIntervals.reduce(0) { $0 + $1.duration } +
                                 deepIntervals.reduce(0) { $0 + $1.duration }
            
            sleepData.totalSleepDuration = totalSleepTime
            
            // Set start and end times based on all intervals
            let allIntervals = awakeIntervals + remIntervals + coreIntervals + deepIntervals
            if let firstInterval = allIntervals.min(by: { $0.startDate < $1.startDate }),
               let lastInterval = allIntervals.max(by: { $0.endDate < $1.endDate }) {
                sleepData.startTime = firstInterval.startDate
                sleepData.endTime = lastInterval.endDate
            }
        } else {
            print("No sleep sessions found")
        }
    }
    
    // Workout Methods
    
    func fetchWorkoutsForDate(_ date: Date) async -> [WorkoutData] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
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
                        totalEnergyBurned: workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)?.sumQuantity()?.doubleValue(for: .kilocalorie()),
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
            
            return workouts
        } catch {
            print("Error fetching workouts: \(error.localizedDescription)")
            return []
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
        
        // Fix for elevation gain - first check workout metadata
        if let metadata = workout.metadata,
           let elevationAscended = metadata[HKMetadataKeyElevationAscended] as? NSNumber {
            // Metadata values are stored in meters, convert to feet
            workoutData.elevationGain = elevationAscended.doubleValue * 3.28084
        } else if let flightsClimbedType = HKObjectType.quantityType(forIdentifier: .flightsClimbed) {
            // Fallback to flightsClimbed if metadata isn't available
            let flightsValue = await fetchWorkoutMetric(
                for: workout,
                quantityType: flightsClimbedType,
                unit: HKUnit.count(),
                options: .cumulativeSum
            )
            // Approximate: 1 flight ≈ 10 feet
            workoutData.elevationGain = flightsValue * 10
        }
        
        // Fix for pace - calculate from distance and duration for running workouts
        if workout.workoutActivityType == .running || workout.workoutActivityType == .walking {
            if let distance = workout.totalDistance?.doubleValue(for: HKUnit.meter()),
               distance > 0 && workout.duration > 0 {
                // Calculate pace in seconds per meter
                let pace = workout.duration / distance
                workoutData.averagePace = pace
            } else {
                // Try to get pace from running speed
                if let speedType = HKObjectType.quantityType(forIdentifier: .runningSpeed) {
                    let speedValue = await fetchWorkoutMetric(
                        for: workout,
                        quantityType: speedType,
                        unit: HKUnit.meter().unitDivided(by: HKUnit.second()),
                        options: .discreteAverage
                    )
                    
                    if speedValue > 0 {
                        // Convert speed to pace (seconds per meter)
                        workoutData.averagePace = 1.0 / speedValue
                    }
                }
            }
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
    
    // Helper to apply cached data for a specific date
    private func applyCachedData(for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        if let cachedHealth = cachedHealthData[startOfDay] {
            healthData = cachedHealth
        }
        
        if let cachedSleep = cachedSleepData[startOfDay] {
            sleepData = cachedSleep
        }
        
        if let cachedSamplesForDate = cachedSamples[startOfDay] {
            heartRateSamples = cachedSamplesForDate.heartRate
            stepsSamples = cachedSamplesForDate.steps
            hrvSamples = cachedSamplesForDate.hrv
            
            if let firstHR = cachedSamplesForDate.heartRate.first {
                latestHeartRate = firstHR.value
            }
            if let firstHRV = cachedSamplesForDate.hrv.first {
                latestHRV = firstHRV.value
            }
        }
        
        // Update workouts
        let workoutsForDate = cachedWorkouts.filter {
            calendar.isDate($0.startDate, inSameDayAs: startOfDay)
        }
        workoutCollection.workouts = workoutsForDate
    }
    
    // Fetch data for a specific date, marking it as fetched if successful
    func fetchHealthDataIfNeeded(for date: Date, inBackground: Bool = false) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // First check if we have cached data for this date
        if !calendar.isDateInToday(date) && fetchedDates[startOfDay] == true {
            // If we have cached data, apply it regardless of background mode
            await MainActor.run {
                applyCachedData(for: date)
                if !inBackground {
                    workoutCollection.selectedDate = date
                }
            }
            return
        }
        
        // If no cached data or it's today, fetch new data
        if shouldFetchDataFor(date) {
            if !inBackground {
                await MainActor.run { loadingDate = date }
            }
            
            await fetchHealthData(for: date, updateSelectedDate: !inBackground, inBackground: inBackground)
            
            // Mark the date as fetched if it's not today
            if !Calendar.current.isDateInToday(date) {
                await MainActor.run {
                    fetchedDates[calendar.startOfDay(for: date)] = true
                    if !inBackground {
                        loadingDate = nil
                    }
                }
            } else {
                await MainActor.run {
                    if !inBackground {
                        loadingDate = nil
                    }
                }
            }
        }
    }
    
    // Helper to check if a date needs to be fetched
    private func shouldFetchDataFor(_ date: Date) -> Bool {
        let calendar = Calendar.current
        // Always fetch today's data
        if calendar.isDateInToday(date) {
            return true
        }
        // For other dates, only fetch if not already fetched
        return fetchedDates[calendar.startOfDay(for: date)] != true
    }
    
    // Add a method to fetch data for the last 30 days
    func fetchLast30DaysData() async {
        let calendar = Calendar.current
        let today = Date()
        
        // Always fetch today's data first (not in background)
        await fetchHealthDataIfNeeded(for: today)
        
        // Create an array of the last 29 days (excluding today)
        let last29Days = (1..<30).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
        
        // Filter out dates that have already been fetched
        let datesToFetch = last29Days.filter { !fetchedDates.keys.contains(calendar.startOfDay(for: $0)) }
        
        if !datesToFetch.isEmpty {
            // Set background loading state
            await MainActor.run { isBackgroundLoading = true }
            
            // Fetch historical data in background
            for date in datesToFetch {
                await fetchHealthDataIfNeeded(for: date, inBackground: true)
            }
            
            await MainActor.run { isBackgroundLoading = false }
        }
    }
}
