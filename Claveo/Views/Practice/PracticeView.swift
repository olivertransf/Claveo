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
    @State private var quickEntry: QuickEntryRequest?
    @State private var showingSettings = false
    @State private var showingWeekPicker = false
    @State private var weekPickerDate = Date()
    @State private var currentWeekOffset: Int? = 0
    @State private var searchText = ""
    @State private var filteredEntries: [PracticeEntry] = []

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
                                .listRowSeparator(.hidden)
                        } else {
                            ContentUnavailableView {
                                Label("No matches", systemImage: "magnifyingglass")
                            } description: {
                                Text("Try a different search term.")
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    } else {
                        ForEach(filteredEntries) { entry in
                            Button {
                                selectedEntry = entry
                            } label: {
                                JournalEntryRow(entry: entry, accentColor: themeManager.accentColor)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                            .claveoListRowChrome(hideSeparator: entry.id == filteredEntries.last?.id)
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
                .listSectionSeparator(.hidden, edges: .bottom)
            }
            .claveoInsetGroupedListStyle()
            .refreshable { await practiceService.refreshFromiCloud() }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .moreTabBackButton(for: 3)
            .listSectionSpacing(12)
            .searchable(text: $searchText, prompt: "Search journal notes")
            .onAppear(perform: refreshFilteredEntries)
            .onChange(of: searchText) { _, _ in
                refreshFilteredEntries()
            }
            .onChange(of: practiceService.practiceEntries) { _, _ in
                refreshFilteredEntries()
            }
            .onChange(of: currentWeekOffset) { _, _ in
                refreshFilteredEntries()
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Practice settings")

                    Button {
                        logPractice(on: selectedDate)
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Log practice session")
                }
            }
            .sheet(item: $selectedEntry) { entry in
                PracticeEntryDetailView(entry: entry)
                    .environmentObject(themeManager)
            }
            .sheet(item: $quickEntry) { request in
                QuickPracticeEntryView(date: request.date, prefersNewEntry: request.prefersNewEntry)
                    .environmentObject(themeManager)
                    .id(request.id)
            }
            .sheet(isPresented: $showingSettings) {
                PracticeSettingsView()
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingWeekPicker) {
                NavigationStack {
                    DatePicker(
                        "Week",
                        selection: $weekPickerDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("Jump to Week")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingWeekPicker = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                Motion.animate { currentWeekOffset = offset(for: weekPickerDate) }
                                showingWeekPicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
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
                iconColor: practiceService.currentStreak > 0 ? Color.themeRating : .secondary
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
                    iconColor: Color.themeRating
                )
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
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
        VStack(alignment: .leading, spacing: 4) {
            weekStripHeader
            weekPager
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 8, trailing: 12))
    }

    private var weekOffsets: [Int] {
        Array(stride(from: -52, through: 52, by: 1))
    }

    private var weekPager: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(weekOffsets, id: \.self) { offset in
                    weekDaysRow(offset: offset)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentWeekOffset, anchor: .center)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: 86)
    }

    private var weekStripHeader: some View {
        HStack {
            Button {
                guard weekOffset > -52 else { return }
                Motion.animate { currentWeekOffset = weekOffset - 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(weekOffset <= -52 ? Color(.tertiaryLabel) : themeManager.accentColor)
                    .frame(width: 44, height: 44)
            }
            .disabled(weekOffset <= -52)
            .accessibilityLabel("Previous week")

            Spacer()

            HStack(spacing: 2) {
                Text(weekTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Button {
                    weekPickerDate = startOfWeek(offset: weekOffset)
                    showingWeekPicker = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(themeManager.accentColor)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Jump to Week")
            }

            Spacer()

            Button {
                guard weekOffset < 52 else { return }
                Motion.animate { currentWeekOffset = weekOffset + 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(weekOffset >= 52 ? Color(.tertiaryLabel) : themeManager.accentColor)
                    .frame(width: 44, height: 44)
            }
            .disabled(weekOffset >= 52)
            .accessibilityLabel("Next week")
        }
    }

    private func weekDaysRow(offset: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { index in
                let date = dateForIndex(index, weekOffset: offset)
                let mins = practiceService.entriesForDate(date).reduce(0) { $0 + $1.duration }
                WeekDayCell(
                    date: date,
                    isToday: calendar.isDateInToday(date),
                    isPracticed: practiceService.hasPracticeOnDate(date),
                    minutesPracticed: mins,
                    accentColor: themeManager.accentColor,
                    onAccent: themeManager.onAccent
                ) {
                    logPractice(on: date)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(themeManager.accentColor)
                .padding(.top, 20)
            VStack(spacing: 6) {
                Text(practiceService.practiceEntries.isEmpty ? "No sessions yet" : "No sessions this week")
                    .font(.headline)
                Text(practiceService.practiceEntries.isEmpty
                     ? "Tap a day above or use + to log your first practice session."
                     : "Tap a day above to log a session for this week.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                logPractice(on: startOfWeek(offset: weekOffset))
            } label: {
                Label("Log Practice", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(themeManager.accentColor)
                    .foregroundStyle(themeManager.onAccent)
                    .clipShape(Capsule(style: .continuous))
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var weekOffset: Int { currentWeekOffset ?? 0 }

    private func startOfWeek(offset: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        return calendar.date(byAdding: .weekOfYear, value: offset, to: start) ?? start
    }

    private func offset(for date: Date) -> Int {
        let target = startOfWeek(offset: 0)
        let selected = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        ) ?? calendar.startOfDay(for: date)
        let weeks = calendar.dateComponents([.weekOfYear], from: target, to: selected).weekOfYear ?? 0
        return min(52, max(-52, weeks))
    }

    private var weekTitle: String {
        switch weekOffset {
        case 0: return String(localized: "This Week")
        case -1: return String(localized: "Last Week")
        case 1: return String(localized: "Next Week")
        default:
            let start = startOfWeek(offset: weekOffset)
            let formatter = PracticeWeekFormatters.monthDay
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        }
    }

    private func dateForIndex(_ index: Int, weekOffset: Int) -> Date {
        let start = startOfWeek(offset: weekOffset)
        return calendar.date(byAdding: .day, value: index, to: start) ?? start
    }

    private func logPractice(on date: Date) {
        let day = calendar.startOfDay(for: date)
        selectedDate = day
        quickEntry = QuickEntryRequest(date: day, prefersNewEntry: true)
    }

    private func refreshFilteredEntries() {
        let start = startOfWeek(offset: weekOffset)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        let weekEntries = practiceService.practiceEntries.filter { entry in
            let day = calendar.startOfDay(for: entry.date)
            return day >= start && day < end
        }
        guard !searchText.isEmpty else {
            filteredEntries = weekEntries
            return
        }
        let q = searchText.lowercased()
        filteredEntries = weekEntries.filter {
            $0.notes?.lowercased().contains(q) == true
            || $0.voiceMemoTranscript?.lowercased().contains(q) == true
            || $0.formattedDate.lowercased().contains(q)
            || "\($0.duration)".contains(q)
            || $0.formattedDuration.lowercased().contains(q)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes)m" : String(format: "%.1fh", Double(minutes) / 60)
    }
}

private enum PracticeWeekFormatters {
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()
}

// MARK: - Week Day Cell

private struct WeekDayCell: View {
    let date: Date
    let isToday: Bool
    let isPracticed: Bool
    let minutesPracticed: Int
    let accentColor: Color
    let onAccent: Color
    let onTap: () -> Void

    private let calendar = Calendar.current
    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 36

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
        return minutesPracticed < 60 ? "\(minutesPracticed)m" : String(format: "%.1fh", Double(minutesPracticed) / 60)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Text(dayLetter)
                    .font(isToday ? .caption.weight(.bold) : .caption)
                    .foregroundStyle(isToday ? accentColor : .secondary)

                ZStack {
                    Circle()
                        .fill(circleBackground)
                        .frame(width: circleSize, height: circleSize)
                    if isToday && !isPracticed {
                        Circle()
                            .strokeBorder(accentColor, lineWidth: 1.5)
                            .frame(width: circleSize, height: circleSize)
                    }
                    Text(dayNumber)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(numberColor)
                }

                Group {
                    if let label = durationLabel {
                        Text(label)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(accentColor)
                    } else {
                        Text(" ")
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(String(localized: "Log a practice session"))
    }

    private var accessibilityValue: String {
        if isPracticed {
            return String(localized: "\(minutesPracticed) minutes practiced")
        }
        if isToday {
            return String(localized: "Today, no practice logged")
        }
        return String(localized: "No practice logged")
    }

    private var circleBackground: Color {
        if isPracticed { return accentColor }
        if isToday { return accentColor.opacity(0.18) }
        return Color(.tertiarySystemFill)
    }

    private var numberColor: Color {
        if isPracticed { return onAccent }
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
        if let notes = entry.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            return notes
        }
        if let transcript = entry.voiceMemoTranscript?.trimmingCharacters(in: .whitespacesAndNewlines), !transcript.isEmpty {
            return transcript
        }
        return nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            dateBadge

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.formattedDuration)
                    .font(.headline)

                if let notes = trimmedNotes {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(entry.formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if trimmedNotes != nil || !entry.linkedRecordingIds.isEmpty {
                    metadataRow
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)

            if let rating = entry.rating {
                ratingStars(rating)
                    .padding(.top, 4)
            }
        }
    }

    private var dateBadge: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(monthAbbrev)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.4)
        }
        .frame(width: 48, height: 52)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            if trimmedNotes != nil {
                Text(entry.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !entry.linkedRecordingIds.isEmpty {
                if trimmedNotes != nil {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
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
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: 11))
                    .foregroundStyle(star <= rating ? Color.themeRating : Color.secondary.opacity(0.45))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Rating, \(rating) out of 5"))
    }
}

// MARK: - Practice Settings View

struct PracticeSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var maximumTime: Int
    @State private var defaultTime: Int
    @State private var durationOptions: [Int]
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var reminderPermissionDenied = false

    init() {
        let settings = SettingsManager.shared.settings
        _maximumTime = State(initialValue: settings.maximumPracticeMinutes)
        _defaultTime = State(initialValue: settings.defaultPracticeTime)
        _durationOptions = State(initialValue: PracticeDuration.sanitizedOptions(
            settings.practiceDurationOptions,
            maximum: settings.maximumPracticeMinutes
        ))
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
                Section("Practice Duration") {
                    PracticeDurationControls(
                        title: String(localized: "Maximum Duration"),
                        minutes: $maximumTime,
                        maximum: PracticeDuration.absoluteMaximum
                    )
                    .padding(.vertical, 4)

                    PracticeDurationControls(
                        title: String(localized: "Default Duration"),
                        minutes: $defaultTime,
                        maximum: maximumTime
                    )
                    .padding(.vertical, 4)

                    QuickDurationOptionsEditor(options: $durationOptions, maximum: maximumTime)
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
        let maximum = PracticeDuration.clampMaximum(maximumTime)
        let cleaned = PracticeDuration.sanitizedOptions(durationOptions, maximum: maximum)
        let timeParts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        settingsManager.updatePracticeDurations(
            maximum: maximum,
            defaultMinutes: defaultTime,
            options: cleaned
        )
        settingsManager.update(\.practiceReminderEnabled, value: reminderEnabled)
        settingsManager.update(\.practiceReminderHour, value: timeParts.hour ?? 18)
        settingsManager.update(\.practiceReminderMinute, value: timeParts.minute ?? 0)

        Task {
            await PracticeReminderNotificationService.sync(with: settingsManager.settings)
            if reminderEnabled {
                let status = await PracticeReminderNotificationService.authorizationStatus()
                reminderPermissionDenied = status == .denied
                if reminderPermissionDenied {
                    settingsManager.update(\.practiceReminderEnabled, value: false)
                    reminderEnabled = false
                    return
                }
            }
            dismiss()
        }
    }
}

private struct QuickEntryRequest: Identifiable {
    let id = UUID()
    var date: Date
    var prefersNewEntry: Bool
}

#Preview {
    PracticeView()
        .environmentObject(ThemeManager.shared)
}
