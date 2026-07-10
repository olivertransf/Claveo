//
//  PracticeView.swift
//  Claveo
//
//  Created by Oliver Tran on 12/22/25.
//
//  Copyright (c) 2025 Oliver Tran

import SwiftUI

// MARK: - Main View

struct PracticeView: View {
    @StateObject private var practiceService = PracticeService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedEntry: PracticeEntry?
    @State private var selectedDate = Date()
    @State private var sheetDate = Date()
    @State private var showingQuickEntry = false
    @State private var showingSettings = false
    @State private var currentWeekOffset = 0
    @State private var searchText = ""

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            List {
                Section {
                    statsBar
                }

                Section {
                    weekStrip
                }

                Section("Journal") {
                    if filteredEntries.isEmpty {
                        if searchText.isEmpty {
                            emptyState
                                .listRowBackground(Color.clear)
                        } else {
                            ContentUnavailableView {
                                Label("No matches", systemImage: "magnifyingglass")
                            } description: {
                                Text("Try a different search term.")
                            }
                            .listRowBackground(Color.clear)
                        }
                    } else {
                        ForEach(filteredEntries) { entry in
                            Button {
                                selectedEntry = entry
                            } label: {
                                JournalEntryRow(entry: entry, accentColor: themeManager.accentColor)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                            .claveoListRowChrome()
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
                }
            }
            .claveoInsetGroupedListStyle()
            .refreshable { await practiceService.refreshFromiCloud() }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .listSectionSpacing(12)
            .searchable(text: $searchText, prompt: "Search journal notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sheetDate = Date()
                        showingQuickEntry = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(item: $selectedEntry) { entry in
                PracticeEntryDetailView(entry: entry)
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingQuickEntry) {
                QuickPracticeEntryView(date: sheetDate)
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingSettings) {
                PracticeSettingsView()
                    .environmentObject(themeManager)
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statItem(
                value: "\(practiceService.currentStreak)",
                label: String(localized: "Day Streak"),
                icon: "flame.fill",
                iconColor: practiceService.currentStreak > 0 ? .orange : .secondary
            )
            statDivider
            statItem(
                value: formatMinutes(practiceService.thisWeekPracticeTime),
                label: String(localized: "This Week"),
                icon: "chart.bar.fill",
                iconColor: themeManager.accentColor
            )
            statDivider
            statItem(
                value: "\(practiceService.totalPracticeDays)",
                label: String(localized: "Total Days"),
                icon: "calendar",
                iconColor: themeManager.accentColor
            )
            if let avg = practiceService.averageRating() {
                statDivider
                statItem(
                    value: String(format: "%.1f", avg),
                    label: String(localized: "Avg Rating"),
                    icon: "star.fill",
                    iconColor: .yellow
                )
            }
        }
        .padding(.vertical, 10)
    }

    private func statItem(value: String, label: String, icon: String, iconColor: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.5))
            .frame(width: 1, height: 34)
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            weekStripHeader
            weekDaysRow
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    private var weekStripHeader: some View {
        HStack {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    if currentWeekOffset > -52 { currentWeekOffset -= 1 }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(currentWeekOffset <= -52 ? Color(.tertiaryLabel) : themeManager.accentColor)
            }
            .disabled(currentWeekOffset <= -52)

            Spacer()

            Text(weekTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    if currentWeekOffset < 0 { currentWeekOffset += 1 }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(currentWeekOffset >= 0 ? Color(.tertiaryLabel) : themeManager.accentColor)
            }
            .disabled(currentWeekOffset >= 0)
        }
    }

    @State private var dragOffset: CGFloat = 0

    private var weekDayItems: [(index: Int, date: Date, isToday: Bool, isPracticed: Bool, isFuture: Bool, mins: Int)] {
        (0..<7).map { index in
            let date = dateForIndex(index)
            let mins = practiceService.entriesForDate(date).reduce(0) { $0 + $1.duration }
            return (
                index,
                date,
                calendar.isDateInToday(date),
                practiceService.hasPracticeOnDate(date),
                date > Date(),
                mins
            )
        }
    }

    private var weekDaysRow: some View {
        HStack(spacing: 6) {
            ForEach(weekDayItems, id: \.index) { item in
                WeekDayCell(
                    date: item.date,
                    isToday: item.isToday,
                    isPracticed: item.isPracticed,
                    isFuture: item.isFuture,
                    minutesPracticed: item.mins,
                    accentColor: themeManager.accentColor
                ) {
                    sheetDate = item.date
                    selectedDate = item.date
                    showingQuickEntry = true
                }
            }
        }
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { dragOffset = $0.translation.width }
                .onEnded { value in
                    withAnimation(.easeOut(duration: 0.2)) {
                        if value.translation.width > 50 && currentWeekOffset > -52 {
                            currentWeekOffset -= 1
                        } else if value.translation.width < -50 && currentWeekOffset < 0 {
                            currentWeekOffset += 1
                        }
                        dragOffset = 0
                    }
                }
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(themeManager.accentColor.opacity(0.5))
                .padding(.top, 20)
            VStack(spacing: 6) {
                Text("No sessions yet")
                    .font(.headline)
                Text("Tap a day above or use + to log your first practice session.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                sheetDate = Date()
                showingQuickEntry = true
            } label: {
                Label("Log Practice", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(themeManager.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule(style: .continuous))
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var weekStart: Date {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        return calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: start) ?? start
    }

    private var weekTitle: String {
        switch currentWeekOffset {
        case 0: return String(localized: "This Week")
        case -1: return String(localized: "Last Week")
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let end = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            return "\(formatter.string(from: weekStart)) – \(formatter.string(from: end))"
        }
    }

    private func dateForIndex(_ index: Int) -> Date {
        calendar.date(byAdding: .day, value: index, to: weekStart) ?? weekStart
    }

    private var filteredEntries: [PracticeEntry] {
        guard !searchText.isEmpty else {
            return Array(practiceService.practiceEntries.prefix(20))
        }
        let q = searchText.lowercased()
        return practiceService.practiceEntries.filter {
            $0.notes?.lowercased().contains(q) == true
            || $0.formattedDate.lowercased().contains(q)
            || $0.formattedDuration.lowercased().contains(q)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes)m" : String(format: "%.1gh", Double(minutes) / 60)
    }
}

// MARK: - Week Day Cell

private struct WeekDayCell: View {
    let date: Date
    let isToday: Bool
    let isPracticed: Bool
    let isFuture: Bool
    let minutesPracticed: Int
    let accentColor: Color
    let onTap: () -> Void

    private let calendar = Calendar.current

    private var dayLetter: String {
        let weekday = calendar.component(.weekday, from: date) - 1
        let symbols = calendar.veryShortWeekdaySymbols
        guard weekday >= 0, weekday < symbols.count else { return "" }
        return symbols[weekday]
    }

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    private var durationLabel: String? {
        guard isPracticed && minutesPracticed > 0 else { return nil }
        return minutesPracticed < 60 ? "\(minutesPracticed)m" : String(format: "%.1gh", Double(minutesPracticed) / 60)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Text(dayLetter)
                    .font(.system(size: 11, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? accentColor : .secondary)

                ZStack {
                    Circle()
                        .fill(circleBackground)
                        .frame(width: 36, height: 36)
                    if isToday && !isPracticed {
                        Circle()
                            .strokeBorder(accentColor, lineWidth: 1.5)
                            .frame(width: 36, height: 36)
                    }
                    Text(dayNumber)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(numberColor)
                }

                // Duration hint or empty spacer for alignment
                Group {
                    if let label = durationLabel {
                        Text(label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(accentColor)
                    } else {
                        Text(" ")
                            .font(.system(size: 9))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(isFuture ? 0.35 : 1)
        .disabled(isFuture)
    }

    private var circleBackground: Color {
        if isPracticed { return accentColor }
        if isToday { return accentColor.opacity(0.08) }
        return Color(.tertiarySystemFill)
    }

    private var numberColor: Color {
        if isPracticed { return .white }
        if isToday { return accentColor }
        return .primary.opacity(0.7)
    }
}

// MARK: - Journal Entry Row

private struct JournalEntryRow: View {
    let entry: PracticeEntry
    let accentColor: Color

    private let calendar = Calendar.current

    private var dayNumber: String {
        "\(calendar.component(.day, from: entry.date))"
    }

    private var monthAbbrev: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: entry.date).uppercased()
    }

    private var trimmedNotes: String? {
        guard let notes = entry.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty else {
            return nil
        }
        return notes
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            dateBadge

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.formattedDuration)
                    .font(.headline)

                if let notes = trimmedNotes {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text(entry.formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if trimmedNotes != nil || !entry.linkedRecordingIds.isEmpty {
                    metadataRow
                }
            }

            Spacer(minLength: 6)

            if let rating = entry.rating {
                ratingStars(rating)
            }
        }
    }

    private var dateBadge: some View {
        VStack(spacing: 1) {
            Text(dayNumber)
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(monthAbbrev)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.4)
        }
        .frame(width: 44, height: 44)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
    }

    private var metadataRow: some View {
        HStack(spacing: 6) {
            if trimmedNotes != nil {
                Text(entry.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if !entry.linkedRecordingIds.isEmpty {
                if trimmedNotes != nil {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 3) {
                    Image(systemName: "waveform")
                        .font(.caption2.weight(.semibold))
                    Text("\(entry.linkedRecordingIds.count)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(accentColor)
            }
        }
    }

    private func ratingStars(_ rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: 10))
                    .foregroundStyle(star <= rating ? .orange : Color(.tertiaryLabel))
            }
        }
    }
}

// MARK: - Practice Settings View

struct PracticeSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var defaultTime: Int
    @State private var durationOptions: [Int]
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var reminderPermissionDenied = false

    init() {
        let settings = SettingsManager.shared.settings
        _defaultTime = State(initialValue: settings.defaultPracticeTime)
        var options = settings.practiceDurationOptions
        options = options.filter { $0 >= 5 && $0 <= 480 }.sorted()
        if options.isEmpty { options = [15, 30, 45, 60] }
        _durationOptions = State(initialValue: options)
        _reminderEnabled = State(initialValue: settings.practiceReminderEnabled)

        var components = DateComponents()
        components.hour = settings.practiceReminderHour
        components.minute = settings.practiceReminderMinute
        let calendar = Calendar.current
        let defaultReminderTime = calendar.date(from: components)
            ?? calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date())
            ?? Date()
        _reminderTime = State(initialValue: defaultReminderTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Default Practice Duration") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(defaultTime) minutes")
                            .font(.title3.weight(.semibold))
                        HStack {
                            ForEach([15, 30, 45, 60, 90], id: \.self) { mins in
                                Button {
                                    defaultTime = mins
                                } label: {
                                    Text("\(mins)")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(defaultTime == mins ? .white : themeManager.accentColor)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(defaultTime == mins ? themeManager.accentColor : themeManager.accentColor.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        }
                        Slider(value: .init(get: { Double(defaultTime) }, set: { defaultTime = Int($0) }), in: 5...180, step: 5)
                            .tint(themeManager.accentColor)
                    }
                    .padding(.vertical, 4)
                }

                Section("Quick Duration Options") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Buttons shown when logging a session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(durationOptions, id: \.self) { option in
                                Button {
                                    durationOptions.removeAll { $0 == option }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("\(option)")
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(themeManager.accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(themeManager.accentColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        }
                        if durationOptions.count < 6 {
                            HStack(spacing: 8) {
                                ForEach([15, 30, 45, 60, 90, 120, 180].filter { !durationOptions.contains($0) }.prefix(5), id: \.self) { mins in
                                    Button {
                                        durationOptions.append(mins)
                                        durationOptions.sort()
                                    } label: {
                                        Text("+\(mins)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(Color(.tertiarySystemFill))
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Toggle("Daily practice reminder", isOn: $reminderEnabled)

                    if reminderEnabled {
                        DatePicker(
                            "Reminder time",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )

                        if reminderPermissionDenied {
                            Button("Open Notification Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                } footer: {
                    if reminderEnabled {
                        if reminderPermissionDenied {
                            Text("Notifications are turned off for Claveo. Enable them in Settings to receive your daily reminder.")
                        } else {
                            Text("You'll get a notification every day at this time.")
                        }
                    } else {
                        Text("Set a daily reminder to help build a consistent practice habit.")
                    }
                }
            }
            .navigationTitle("Practice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(themeManager.accentColor)
            .task(id: reminderEnabled) {
                guard reminderEnabled else {
                    reminderPermissionDenied = false
                    return
                }
                let status = await PracticeReminderNotificationService.authorizationStatus()
                reminderPermissionDenied = status == .denied
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        savePracticeSettings()
                    }
                }
            }
        }
    }

    private func savePracticeSettings() {
        var cleaned = durationOptions.filter { $0 >= 5 && $0 <= 480 }.sorted()
        if cleaned.isEmpty { cleaned = [15, 30, 45, 60] }

        let timeParts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        settingsManager.update(\.defaultPracticeTime, value: defaultTime)
        settingsManager.update(\.practiceDurationOptions, value: cleaned)
        settingsManager.update(\.practiceReminderEnabled, value: reminderEnabled)
        settingsManager.update(\.practiceReminderHour, value: timeParts.hour ?? 18)
        settingsManager.update(\.practiceReminderMinute, value: timeParts.minute ?? 0)

        Task {
            await PracticeReminderNotificationService.sync(with: settingsManager.settings)
            if reminderEnabled {
                let status = await PracticeReminderNotificationService.authorizationStatus()
                reminderPermissionDenied = status == .denied
                if reminderPermissionDenied {
                    return
                }
            }
            dismiss()
        }
    }
}

#Preview {
    PracticeView()
        .environmentObject(ThemeManager.shared)
}
