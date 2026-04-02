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
            ScrollView {
                VStack(spacing: 28) {
                    statsBar
                    weekStrip
                    journalSection
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .refreshable { await practiceService.refreshFromiCloud() }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.large)
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
            }
            .sheet(isPresented: $showingQuickEntry) {
                QuickPracticeEntryView(date: sheetDate)
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
                label: "Day Streak",
                icon: "flame.fill",
                iconColor: practiceService.currentStreak > 0 ? .orange : .secondary
            )
            statDivider
            statItem(
                value: formatMinutes(practiceService.thisWeekPracticeTime),
                label: "This Week",
                icon: "chart.bar.fill",
                iconColor: themeManager.accentColor
            )
            statDivider
            statItem(
                value: "\(practiceService.totalPracticeDays)",
                label: "Total Days",
                icon: "calendar",
                iconColor: themeManager.accentColor
            )
            if let avg = practiceService.averageRating() {
                statDivider
                statItem(
                    value: String(format: "%.1f", avg),
                    label: "Avg Rating",
                    icon: "star.fill",
                    iconColor: .yellow
                )
            }
        }
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 20)
    }

    private func statItem(value: String, label: String, icon: String, iconColor: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
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
            .frame(width: 1, height: 40)
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 14) {
            weekStripHeader
            weekDaysRow
        }
        .padding(.horizontal, 20)
    }

    private var weekStripHeader: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
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

    private var weekDaysRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { index in
                let date = dateForIndex(index)
                let isToday = calendar.isDateInToday(date)
                let isPracticed = practiceService.hasPracticeOnDate(date)
                let isFuture = date > Date()
                let mins = practiceService.entriesForDate(date).reduce(0) { $0 + $1.duration }

                WeekDayCell(
                    date: date,
                    isToday: isToday,
                    isPracticed: isPracticed,
                    isFuture: isFuture,
                    minutesPracticed: mins,
                    accentColor: themeManager.accentColor
                ) {
                    sheetDate = date
                    selectedDate = date
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        showingQuickEntry = true
                    }
                }
            }
        }
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { dragOffset = $0.translation.width }
                .onEnded { value in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
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

    // MARK: - Journal Section

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Journal")
                    .font(.title3.weight(.bold))
                Spacer()
                if !practiceService.practiceEntries.isEmpty {
                    Text("\(practiceService.practiceEntries.count) sessions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

            if filteredEntries.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredEntries) { entry in
                        SessionCard(entry: entry, accentColor: themeManager.accentColor)
                            .padding(.horizontal, 20)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedEntry = entry }
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
    }

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
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private var weekStart: Date {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        return calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: start) ?? start
    }

    private var weekTitle: String {
        switch currentWeekOffset {
        case 0: return "This Week"
        case -1: return "Last Week"
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
    private static let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    private var dayLetter: String {
        let weekday = calendar.component(.weekday, from: date) - 1
        return Self.dayLetters[weekday]
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
        .buttonStyle(.plain)
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

// MARK: - Session Card

private struct SessionCard: View {
    let entry: PracticeEntry
    let accentColor: Color

    private let calendar = Calendar.current

    private var dayNumber: String {
        "\(calendar.component(.day, from: entry.date))"
    }

    private var monthAbbrev: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: entry.date).uppercased()
    }

    private var dayName: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: entry.date).uppercased()
    }

    private var accentBarColor: Color {
        guard let rating = entry.rating else { return accentColor.opacity(0.4) }
        switch rating {
        case 5: return .orange
        case 4: return accentColor
        case 3: return accentColor.opacity(0.7)
        default: return .secondary.opacity(0.4)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Accent bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentBarColor)
                .frame(width: 4)
                .padding(.vertical, 12)

            // Date block
            VStack(spacing: 1) {
                Text(dayNumber)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(monthAbbrev)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(0.5)
                Text(dayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .kerning(0.3)
            }
            .frame(width: 52)
            .padding(.vertical, 14)

            // Separator
            Rectangle()
                .fill(Color(.separator).opacity(0.4))
                .frame(width: 0.5)
                .padding(.vertical, 16)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(entry.formattedDuration)
                        .font(.headline)
                    Spacer()
                    if let rating = entry.rating {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundStyle(star <= rating ? Color.orange : Color(.tertiaryLabel))
                            }
                        }
                    }
                }

                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !entry.linkedRecordingIds.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                        Text("\(entry.linkedRecordingIds.count) recording\(entry.linkedRecordingIds.count == 1 ? "" : "s")")
                            .font(.caption2)
                    }
                    .foregroundStyle(accentColor.opacity(0.8))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.trailing, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Practice Settings View

struct PracticeSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var defaultTime: Int
    @State private var durationOptions: [Int]

    init() {
        _defaultTime = State(initialValue: SettingsManager.shared.settings.defaultPracticeTime)
        var options = SettingsManager.shared.settings.practiceDurationOptions
        options = options.filter { $0 >= 5 && $0 <= 480 }.sorted()
        if options.isEmpty { options = [15, 30, 45, 60] }
        _durationOptions = State(initialValue: options)
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
                                .buttonStyle(.plain)
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
                                .buttonStyle(.plain)
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
                                    .buttonStyle(.plain)
                                }
                            }
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
                        var cleaned = durationOptions.filter { $0 >= 5 && $0 <= 480 }.sorted()
                        if cleaned.isEmpty { cleaned = [15, 30, 45, 60] }
                        settingsManager.update(\.defaultPracticeTime, value: defaultTime)
                        settingsManager.update(\.practiceDurationOptions, value: cleaned)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PracticeView()
        .environmentObject(ThemeManager.shared)
}
