//
//  DateCarouselView.swift
//  Basal
//
//  Created by Harish Kilaru on 2/28/25.
//

import SwiftUI

struct DateCarouselView: View {
    @Binding var selectedDate: Date
    var onDateSelected: (Date) -> Void
    
    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Start week on Monday (1 is Sunday, 2 is Monday)
        return cal
    }()
    
    // Number of past weeks to show (no future weeks)
    private let weekCount = 8
    
    // Calculate the initial tab index based on the selected date
    private var initialTabIndex: Int {
        let today = Date()
        
        // Find the start of the current week (Monday)
        let currentWeekday = calendar.component(.weekday, from: today)
        let daysToSubtract = (currentWeekday + 5) % 7 // Convert to Monday-based (2-8)
        let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today)!
        
        // Find the start of the selected date's week
        let selectedWeekday = calendar.component(.weekday, from: selectedDate)
        let selectedDaysToSubtract = (selectedWeekday + 5) % 7
        let selectedWeekStart = calendar.date(byAdding: .day, value: -selectedDaysToSubtract, to: selectedDate)!
        
        // Calculate the difference in weeks
        let components = calendar.dateComponents([.weekOfYear], from: selectedWeekStart, to: currentWeekStart)
        let weekDifference = components.weekOfYear ?? 0
        
        // Ensure the index is within bounds (0 to weekCount-1)
        return min(max(weekDifference, 0), weekCount - 1)
    }
    
    @State private var currentTabIndex: Int = 0
    
    var body: some View {
        VStack(spacing: 4) {
            // Day of week row (Monday to Sunday)
            HStack(spacing: 12) { 
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }
            }
            
            // Date carousel
            TabView(selection: $currentTabIndex) {
                ForEach((0..<weekCount).reversed(), id: \.self) { weekIndex in
                    WeekView(
                        weekIndex: weekIndex,
                        selectedDate: $selectedDate,
                        calendar: calendar,
                        onDateSelected: onDateSelected
                    )
                    .tag(weekIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 60)
            .onAppear {
                currentTabIndex = initialTabIndex
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // Get days of week starting with Monday
    private var daysOfWeek: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE" // Single letter day abbreviation
        
        var days: [String] = []
        // Start with Monday (2) and wrap around to Sunday (1)
        for weekday in 2...8 {
            let adjustedWeekday = weekday <= 7 ? weekday : 1
            let date = calendar.date(from: DateComponents(weekday: adjustedWeekday))!
            days.append(formatter.string(from: date))
        }
        return days
    }
}

struct WeekView: View {
    let weekIndex: Int
    @Binding var selectedDate: Date
    let calendar: Calendar
    var onDateSelected: (Date) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<7, id: \.self) { dayIndex in
                let date = dateFor(weekIndex: weekIndex, dayIndex: dayIndex)
                DateCircleView(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(date),
                    isFuture: calendar.compare(date, to: Date(), toGranularity: .day) == .orderedDescending
                )
                .frame(width: 40)
                .onTapGesture {
                    // Only allow selection of past or today dates
                    if calendar.compare(date, to: Date(), toGranularity: .day) != .orderedDescending {
                        selectedDate = date
                        onDateSelected(date)
                    }
                }
            }
        }
    }
    
    // Calculate date for a specific week and day index
    private func dateFor(weekIndex: Int, dayIndex: Int) -> Date {
        let today = Date()
        
        // Find the start of the current week (Monday)
        let currentWeekday = calendar.component(.weekday, from: today)
        let daysToSubtract = (currentWeekday + 5) % 7 // Convert to Monday-based (2-8)
        let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today)!
        
        // Go back weekIndex weeks
        let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekIndex, to: currentWeekStart)!
        
        // Add dayIndex days to get the specific date
        return calendar.date(byAdding: .day, value: dayIndex, to: weekStart)!
    }
}

struct DateCircleView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isFuture: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(textColor)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(backgroundColor)
            )
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .red
        } else {
            return Color.clear
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .red
        } else if isFuture {
            return .gray.opacity(0.5)
        } else {
            return .primary
        }
    }
} 
