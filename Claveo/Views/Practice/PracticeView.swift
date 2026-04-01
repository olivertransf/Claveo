//
//  PracticeView.swift
//  Claveo
//
//  Created by Oliver Tran on 12/22/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

struct PracticeView: View {
    @StateObject private var practiceService = PracticeService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedEntry: PracticeEntry?
    @State private var selectedDate = Date()
    @State private var sheetDate = Date() // Separate date for the sheet to ensure correct value
    @State private var showingQuickEntry = false
    @State private var showingSettings = false
    @State private var currentWeekOffset = 0 // 0 = this week, -1 = last week, etc.
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Compact Stats Header
                    CompactStatsView()
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // Weekly Habit Tracker with Navigation
                    WeeklyHabitTracker(
                        selectedDate: $selectedDate,
                        sheetDate: $sheetDate,
                        showingQuickEntry: $showingQuickEntry,
                        weekOffset: $currentWeekOffset
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)

                    // Recent Practice Sessions
                    VStack(alignment: .leading, spacing: 12) {
                        Text(searchText.isEmpty ? "Recent Sessions" : "Search Results")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if filteredEntries.isEmpty {
                            if searchText.isEmpty {
                                EmptyPracticeState()
                                    .padding(.horizontal)
                                    .padding(.vertical, 20)
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                    Text("No entries found")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }
                        } else {
                            List {
                                ForEach(filteredEntries) { entry in
                                    PracticeEntryCard(entry: entry)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedEntry = entry
                                        }
                                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                practiceService.deleteEntry(entry)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            
                                            Button {
                                                selectedEntry = entry
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(themeManager.accentColor)
                                        }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .frame(height: CGFloat(min(filteredEntries.count, 10)) * 110 + 16)
                            .scrollDisabled(true)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .refreshable {
                await practiceService.refreshFromiCloud()
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search journal notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(item: $selectedEntry) { entry in
                PracticeEntryDetailView(entry: entry)
            }
            .sheet(isPresented: $showingQuickEntry) {
                QuickPracticeEntryView(date: sheetDate)
            }
            .sheet(isPresented: $showingSettings) {
                PracticeSettingsView()
            }
        }
    }
    
    private var filteredEntries: [PracticeEntry] {
        if searchText.isEmpty {
            return Array(practiceService.practiceEntries.prefix(7))
        } else {
            let searchLower = searchText.lowercased()
            return practiceService.practiceEntries.filter { entry in
                // Search in notes
                if let notes = entry.notes, !notes.isEmpty {
                    if notes.lowercased().contains(searchLower) {
                        return true
                    }
                }
                // Also search in formatted date and duration
                if entry.formattedDate.lowercased().contains(searchLower) {
                    return true
                }
                if entry.formattedDuration.lowercased().contains(searchLower) {
                    return true
                }
                return false
            }
        }
    }
}

// Compact Stats View
struct CompactStatsView: View {
    @StateObject private var practiceService = PracticeService.shared
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            CompactStat(
                value: "\(practiceService.currentStreak)",
                label: "Streak",
                icon: "flame.fill",
                color: .orange
            )

            CompactStat(
                value: formatDuration(practiceService.thisWeekPracticeTime),
                label: "This Week",
                icon: "chart.bar.fill",
                color: themeManager.accentColor
            )

            CompactStat(
                value: "\(practiceService.totalPracticeDays)",
                label: "Days",
                icon: "calendar",
                color: themeManager.accentColor
            )

            if let avgRating = practiceService.averageRating() {
                CompactStat(
                    value: String(format: "%.1f", avgRating),
                    label: "Avg",
                    icon: "star.fill",
                    color: .yellow
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = Double(minutes) / 60.0
            // Format to 2 decimal places, removing trailing zeros
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.numberStyle = .decimal
            if let formatted = formatter.string(from: NSNumber(value: hours)) {
                return "\(formatted)h"
            }
            return String(format: "%.1f", hours) + "h"
        }
    }
}

struct CompactStat: View {
    let value: String
    let label: String
    var icon: String? = nil
    var color: Color? = nil

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(color ?? .blue)
                    .font(.caption)
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8))
        .background(Color.white.opacity(0.05)) // Subtle overlay for better light mode appearance
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Weekly Habit Tracker
struct WeeklyHabitTracker: View {
    @StateObject private var practiceService = PracticeService.shared
    @Binding var selectedDate: Date
    @Binding var sheetDate: Date
    @Binding var showingQuickEntry: Bool
    @Binding var weekOffset: Int
    @EnvironmentObject var themeManager: ThemeManager

    private let calendar = Calendar.current
    private let weekDays = ["S", "M", "T", "W", "T", "F", "S"] // Sunday through Saturday

    private var weekStart: Date {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return today
        }
        guard let offsetDate = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: start) else {
            return start
        }
        return offsetDate
    }

    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if weekOffset > -52 { // Allow going back up to a year
                            weekOffset -= 1
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(themeManager.accentColor)
                }
                .disabled(weekOffset <= -52)

                Spacer()

                Text(weekTitle)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if weekOffset < 0 {
                            weekOffset += 1
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(themeManager.accentColor)
                }
                .disabled(weekOffset >= 0)
            }

            HStack(spacing: 8) {
                ForEach(0..<7) { index in
                    DayCircle(
                        dayIndex: index,
                        isSelected: isSelected(index),
                        isCompleted: hasPracticeOnDay(index),
                        weekDays: weekDays,
                        onTap: {
                            let date = getDateForIndex(index)
                            selectedDate = date
                            sheetDate = date
                            // Delay sheet presentation to ensure state is updated
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                showingQuickEntry = true
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8))
            .background(Color.white.opacity(0.05)) // Subtle overlay for better light mode appearance
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if value.translation.width > threshold && weekOffset > -52 { // Allow going back up to a year
                                weekOffset -= 1
                            } else if value.translation.width < -threshold && weekOffset < 0 {
                                weekOffset += 1
                            }
                            dragOffset = 0
                        }
                    }
            )
        }
        .onChange(of: weekOffset) { _, _ in
            // Reset to current week if we go too far forward
            if weekOffset > 0 {
                weekOffset = 0
            }
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            // Update weekOffset if selectedDate is in a different week
            let selectedWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: newValue)) ?? newValue
            let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
            
            if let weeksDifference = calendar.dateComponents([.weekOfYear], from: currentWeekStart, to: selectedWeekStart).weekOfYear {
                weekOffset = -weeksDifference
            }
        }
    }

    private var weekTitle: String {
        if weekOffset == 0 {
            return "This Week"
        } else if weekOffset == -1 {
            return "Last Week"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let endDate = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            return "\(formatter.string(from: weekStart)) - \(formatter.string(from: endDate))"
        }
    }

    private func isSelected(_ index: Int) -> Bool {
        let date = getDateForIndex(index)
        let selectedDay = calendar.startOfDay(for: selectedDate)
        return calendar.isDate(date, inSameDayAs: selectedDay)
    }
    
    private func isToday(_ index: Int) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let date = getDateForIndex(index)
        return calendar.isDate(date, inSameDayAs: today)
    }

    private func hasPracticeOnDay(_ index: Int) -> Bool {
        let date = getDateForIndex(index)
        return practiceService.hasPracticeOnDate(date)
    }

    private func getDateForIndex(_ index: Int) -> Date {
        guard let date = calendar.date(byAdding: .day, value: index, to: weekStart) else {
            return weekStart
        }
        return date
    }

    private func getEntryForDate(_ date: Date) -> PracticeEntry? {
        return practiceService.entriesForDate(date).first
    }

    private func formattedDateForDebug(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct DayCircle: View {
    let dayIndex: Int
    let isSelected: Bool
    let isCompleted: Bool
    let weekDays: [String]
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 6) {
            Text(weekDays[dayIndex])
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? themeManager.accentColor : .primary.opacity(0.7))

            ZStack {
                // Outer circle background
                Circle()
                    .fill(isCompleted ? themeManager.accentColor.opacity(0.2) : Color(uiColor: .tertiarySystemFill))
                    .frame(width: 36, height: 36)

                // Selected border - make it brighter and bigger
                if isSelected {
                    Circle()
                        .stroke(themeManager.accentColor, lineWidth: 4)
                        .frame(width: 40, height: 40)
                }

                // Completed fill
                if isCompleted {
                    Circle()
                        .fill(themeManager.accentColor.opacity(0.6))
                        .frame(width: 28, height: 28)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// Practice Entry Card
struct PracticeEntryCard: View {
    let entry: PracticeEntry
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.formattedDate)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(entry.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    if let rating = entry.rating {
                        HStack(spacing: 1) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 10))
                            }
                        }
                    }

                    if entry.notes?.isEmpty == false {
                        Image(systemName: "doc.text")
                            .foregroundColor(themeManager.accentColor)
                            .font(.caption2)
                    }

                    if !entry.linkedRecordingIds.isEmpty {
                        Image(systemName: "waveform")
                            .foregroundColor(themeManager.accentColor)
                            .font(.caption2)
                    }
                }
                
                // Show notes preview if available
                if let notes = entry.notes, !notes.isEmpty {
                    Text("\"\(notes)\"")
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8))
        .background(Color.white.opacity(0.05)) // Subtle overlay for better light mode appearance
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Empty State
struct EmptyPracticeState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No practice sessions yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Tap a day above to log your first practice")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 40)
    }
}

// Practice Settings View
struct PracticeSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var defaultTime: Int
    @State private var durationOptions: [Int]

    init() {
        _defaultTime = State(initialValue: SettingsManager.shared.settings.defaultPracticeTime)

        // Validate and clean up duration options
        var options = SettingsManager.shared.settings.practiceDurationOptions
        options = options.filter { $0 >= 5 && $0 <= 480 }.sorted()
        if options.isEmpty {
            options = [15, 30, 45, 60] // Default fallback
        }
        _durationOptions = State(initialValue: options)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Default Practice Duration") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("\(defaultTime) minutes")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Spacer()
                        }

                        HStack {
                            ForEach([15, 30, 45, 60, 90], id: \.self) { mins in
                                Button {
                                    defaultTime = mins
                                } label: {
                                    Text("\(mins)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(defaultTime == mins ? .white : themeManager.accentColor)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(defaultTime == mins ? themeManager.accentColor : themeManager.accentColor.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Slider(value: .init(get: { Double(defaultTime) }, set: { defaultTime = Int($0) }),
                               in: 5...180, step: 5)
                            .tint(themeManager.accentColor)
                    }
                    .padding(.vertical, 4)
                }

                Section("Quick Duration Options") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Customize the duration buttons that appear when adding practice sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            ForEach(durationOptions, id: \.self) { option in
                                Button {
                                    // Remove this duration option
                                    durationOptions.removeAll { $0 == option }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("\(option)")
                                            .font(.subheadline)
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                    }
                                    .foregroundColor(themeManager.accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(themeManager.accentColor.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if durationOptions.count < 6 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Add duration option:")
                                    .font(.subheadline)

                                HStack {
                                    ForEach([15, 30, 45, 60, 90, 120, 180], id: \.self) { mins in
                                        if !durationOptions.contains(mins) && durationOptions.count < 6 {
                                            Button {
                                                if !durationOptions.contains(mins) {
                                                    durationOptions.append(mins)
                                                    durationOptions.sort()
                                                }
                                            } label: {
                                                Text("\(mins)")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 6)
                                                    .background(Color.secondary.opacity(0.1))
                                                    .cornerRadius(8)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        if durationOptions.isEmpty {
                            Text("No duration options set. Add some options above.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Practice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Validate and clean up duration options
                        var cleanedOptions = durationOptions.filter { $0 >= 5 && $0 <= 480 }.sorted()
                        if cleanedOptions.isEmpty {
                            cleanedOptions = [15, 30, 45, 60] // Default fallback
                        }

                        settingsManager.update(\.defaultPracticeTime, value: defaultTime)
                        settingsManager.update(\.practiceDurationOptions, value: cleanedOptions)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PracticeView()
}